// HaloSync — App/AppEnvironment.swift
// Dependency Injection container for HaloSync.
// All services are created here at app startup and injected into the view hierarchy
// via SwiftUI @EnvironmentObject.
//
// Design: AppEnvironment owns service lifetimes.
//         ViewModels are thin — they hold refs to services, not service logic.

import Foundation
import SwiftUI

// MARK: - AppEnvironment

/// The central DI container.
/// Created once at app startup. Lives for the entire app lifetime.
@MainActor
public final class AppEnvironment: ObservableObject {

    // MARK: - Services (Owned)

    public let settings: HaloSyncSettingsStore
    public let displayDiscovery: DisplayDiscovery
    public let permissionHandler: PermissionHandler
    public let controllerMonitor: ControllerMonitor
    public let fluidEngine: FluidEngine
    public let modeDetector: ModeDetector
    public let effectsEngine: EffectsEngine
    public let profileStore: UserDefaultsProfileStore
    public let diagnostics: DiagnosticsService
    public let pipeline: AmbientPipeline

    // MARK: - Init

    public init() {
        // Instantiate from the bottom of the dependency graph upward.
        let loadedSettings = HaloSyncSettings.load()
        let diag           = DiagnosticsService()
        let fluid          = FluidEngine()

        self.settings          = HaloSyncSettingsStore(initial: loadedSettings)
        self.displayDiscovery  = DisplayDiscovery()
        self.permissionHandler = PermissionHandler()
        self.controllerMonitor = ControllerMonitor()
        self.fluidEngine       = fluid
        self.modeDetector      = ModeDetector()
        self.effectsEngine     = EffectsEngine()
        self.profileStore      = UserDefaultsProfileStore()
        self.diagnostics       = diag
        self.pipeline          = AmbientPipeline(fluid: fluid, diagnostics: diag, effects: self.effectsEngine)

        var lastSettings = loadedSettings
        self.settings.onSettingsChanged = { [weak self] newSettings in
            guard let self else { return }
            
            let modeChanged = newSettings.activeMode != lastSettings.activeMode
            let effectChanged = newSettings.activeEffectID != lastSettings.activeEffectID
            
            HaloLogger.app.info("AppEnvironment: Settings changed, updating pipeline. Brightness: \(newSettings.brightness)")
            self.pipeline.updateSettings(newSettings)
            
            if modeChanged || (effectChanged && newSettings.activeMode == .effects) {
                Task {
                    await self.restartPipeline()
                }
            }
            
            lastSettings = newSettings
        }

        HaloLogger.app.info("AppEnvironment initialized")
    }

    // MARK: - Display State

    @Published public private(set) var currentDisplays: [DisplayInfo] = []

    // MARK: - Startup Sequence

    /// Runs the full app startup sequence.
    /// Order matters: permissions → display → controller → (if all OK) start capture.
    public func startup() async {
        HaloLogger.app.info("Starting HaloSync startup sequence...")

        // 1. Request screen recording permission (non-blocking if already granted).
        let permission = await permissionHandler.requestPermission()
        guard permission == .granted else {
            HaloLogger.app.warning("Screen Recording permission not granted.")
            return
        }

        // 2. Start tracking displays
        Task { [weak self] in
            guard let self else { return }
            for await displays in displayDiscovery.displayChanges() {
                self.currentDisplays = displays
                HaloLogger.app.info("Discovered \(displays.count) display(s).")
                
                // If the currently selected display is no longer available, fall back to main
                if let selected = settings.value.selectedDisplayUUID, !displays.contains(where: { $0.uuid == selected }) {
                    if let main = displays.first(where: { $0.isMain }) {
                        settings.value.selectedDisplayUUID = main.uuid
                        if pipeline.isRunning {
                            await selectDisplay(uuid: main.uuid)
                        }
                    }
                }
            }
        }

        // 3. Begin controller discovery.
        controllerMonitor.startDiscovery(storedAddress: settings.value.lastKnownControllerAddress)

        HaloLogger.app.info("Startup sequence complete.")
    }

    // MARK: - Pipeline Control

    /// Starts the ambient lighting pipeline using the currently discovered display and controller.
    public func startPipeline() async {
        guard !pipeline.isRunning else { return }
        
        if settings.value.activeMode == .effects {
            await applyHardwareEffect()
            return
        }

        // Pick the selected display, or fall back to main.
        let displays = displayDiscovery.currentDisplays()
        
        let targetDisplay: DisplayInfo?
        if let selectedUUID = settings.value.selectedDisplayUUID, let match = displays.first(where: { $0.uuid == selectedUUID }) {
            targetDisplay = match
        } else {
            targetDisplay = displays.first(where: { $0.isMain }) ?? displays.first
        }
        
        guard let display = targetDisplay else {
            HaloLogger.app.warning("No display found — cannot start pipeline.")
            return
        }

        // Require a connected controller.
        guard let device = controllerMonitor.discoveredDevice else {
            HaloLogger.app.warning("No controller found — cannot start pipeline.")
            return
        }

        await pipeline.start(display: display, device: device, settings: settings.value)
        diagnostics.updateDevice(info: device)
        diagnostics.updateMonitor(name: display.name)
    }
    
    /// Changes the active display and restarts the pipeline if it is running.
    public func selectDisplay(uuid: String) async {
        settings.value.selectedDisplayUUID = uuid
        if pipeline.isRunning {
            await stopPipeline()
            await startPipeline()
        }
    }
    
    /// Forces the pipeline to restart (useful to apply certain layout/crop changes if they do not update live).
    public func restartPipeline() async {
        if pipeline.isRunning {
            await stopPipeline()
            await startPipeline()
        } else if settings.value.activeMode == .effects {
            await applyHardwareEffect()
        }
    }

    // MARK: - Power Control

    @Published public private(set) var isDeviceOn: Bool = true

    /// Physically turns the LED strip on or off via JSON API.
    public func toggleDevicePower(isOn: Bool) async {
        guard let device = controllerMonitor.discoveredDevice else { return }
        self.isDeviceOn = isOn

        guard let req = WLEDJSONProtocol.powerRequest(host: device.address, isOn: isOn) else { return }
        do {
            let (_, _) = try await URLSession.shared.data(for: req)
            HaloLogger.app.info("Device power set to \(isOn)")
            
            // If turning off, also stop the pipeline if it's running
            if !isOn && pipeline.isRunning {
                await stopPipeline()
            }
        } catch {
            HaloLogger.network.warning("Failed to toggle power: \(error)")
        }
    }
    
    /// Sends a JSON API command to apply a permanent hardware effect to the controller, 
    /// taking into account the user's Wall Color Match compensation if applicable.
    public func applyHardwareEffect() async {
        guard let device = controllerMonitor.discoveredDevice else { return }
        
        let s = settings.value
        guard let effect = EffectsEngine.allEffects.first(where: { $0.id == s.activeEffectID }) else { return }
        let hwConfig = effect.wledHardwareEffect
        var targetColor: SIMD3<Float>? = nil
        
        if hwConfig.usesSolidColor {
            let pSettings = ProcessingSettings.from(
                mode: s.activeMode,
                brightness: s.brightness,
                ambientStrength: s.ambientStrength,
                wallColor: s.wallColor
            )
            
            let comp = pSettings.wallCompensation
            targetColor = SIMD3<Float>(
                s.solidColor.x * comp.x,
                s.solidColor.y * comp.y,
                s.solidColor.z * comp.z
            )
        }
        
        guard let req = WLEDJSONProtocol.hardwareEffectRequest(host: device.address, config: hwConfig, color: targetColor) else { return }
        do {
            let (_, _) = try await URLSession.shared.data(for: req)
            HaloLogger.app.info("Applied hardware effect: \(hwConfig.fxID)")
        } catch {
            HaloLogger.network.warning("Failed to apply hardware effect: \(error)")
        }
    }

    /// Stops the pipeline.
    public func stopPipeline() async {
        await pipeline.stop()
    }
}


// MARK: - HaloSyncSettingsStore

/// Observable wrapper around HaloSyncSettings.
/// Automatically persists on every change.
@MainActor
public final class HaloSyncSettingsStore: ObservableObject {
    public var onSettingsChanged: ((HaloSyncSettings) -> Void)?

    @Published public var value: HaloSyncSettings {
        didSet { 
            value.save() 
            onSettingsChanged?(value)
        }
    }

    public init(initial: HaloSyncSettings) {
        self.value = initial
    }
}
