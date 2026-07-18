// HaloSync — Engine/AmbientPipeline.swift
// The heart of HaloSync. Wires the full pipeline:
//
//   SCKCaptureEngine → MetalProcessor → FluidEngine → WLEDUDPController
//
// Start/stop controls the entire chain atomically.
// Exposes @Published state for the UI to observe.

import Foundation
import SwiftUI

// MARK: - AmbientPipeline

/// Manages the full real-time ambient lighting pipeline.
/// One pipeline runs per active session. Replacing the display or controller
/// requires stopping and restarting.
@MainActor
public final class AmbientPipeline: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var currentFPS: Double = 0
    @Published public private(set) var latencyMs: Double = 0
    @Published public private(set) var gpuMs: Double = 0

    // MARK: - Dependencies

    private let capture:     SCKCaptureEngine
    private let metal:       MetalProcessor?
    private let fluid:       FluidEngine
    private let diagnostics: DiagnosticsService

    // MARK: - Private State

    private var pipelineTask: Task<Void, Never>?
    private var controller:   WLEDUDPController?
    private var keepAliveTask: Task<Void, Never>?

    // MARK: - Init

    public init(fluid: FluidEngine, diagnostics: DiagnosticsService) {
        self.capture     = SCKCaptureEngine()
        self.metal       = try? MetalProcessor()
        self.fluid       = fluid
        self.diagnostics = diagnostics

        if self.metal == nil {
            HaloLogger.metal.warning("MetalProcessor unavailable — GPU sampling disabled.")
        }
    }

    // MARK: - Public API

    /// Starts the full pipeline: capture → process → output.
    /// - Parameters:
    ///   - display:    The display to capture.
    ///   - device:     The LED controller to send frames to.
    ///   - settings:   Current user settings (LED count, brightness, etc.).
    public func start(display: DisplayInfo, device: DeviceInfo, settings: HaloSyncSettings) async {
        guard !isRunning else { return }

        HaloLogger.app.info("AmbientPipeline: starting for \(display.name) → \(device.name)")

        // 1. Connect UDP controller.
        let udpController = WLEDUDPController(
            deviceInfo: device,
            protocol:   settings.activeProtocol
        )
        do {
            try await udpController.connect(to: device.address, port: device.port)
        } catch {
            HaloLogger.network.error("Pipeline failed to connect controller: \(error)")
            return
        }
        self.controller = udpController

        // 2. Start capture stream.
        let frameStream: AsyncStream<CaptureFrame>
        do {
            frameStream = try await capture.start(display: display)
        } catch {
            HaloLogger.capture.error("Pipeline failed to start capture: \(error)")
            await udpController.disconnect()
            return
        }

        isRunning = true

        // 3. Run the pipeline loop in a background task.
        let ledCount = device.ledCount
        let layout = LEDZoneLayout.symmetric(total: ledCount)
        
        self.updateSettings(settings)

        // Keep-alive task for static screens. WLED reverts to internal effects after 2500ms
        // of no DDP packets. If SCK drops frames because the screen is static, we must resend.
        keepAliveTask = Task { [weak self, weak udpController] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, let ctrl = udpController else { break }
                
                let (frame, time) = (self.lastSentFrame, self.lastFrameTime)
                if let frame, time.duration(to: .now) >= .seconds(1) {
                    try? await ctrl.send(frame: frame)
                }
            }
        }

        pipelineTask = Task.detached(priority: .userInteractive) { [weak self] in
            guard let self else { return }

            for await frame in frameStream {
                guard !Task.isCancelled else { break }
                let m = self.metal
                let f = self.fluid
                let d = self.diagnostics
                
                let (liveBrightness, liveSettings) = await MainActor.run {
                    (self._currentBrightness, self._currentProcessingSettings)
                }

                await self.processFrame(
                    frame:              frame,
                    layout:             layout,
                    processingSettings: liveSettings,
                    brightness:         liveBrightness,
                    controller:         udpController,
                    metal:              m,
                    fluid:              f,
                    diagnostics:        d
                )
            }
        }

        HaloLogger.app.info("AmbientPipeline: running ✓")
    }

    /// Stops the pipeline and disconnects the controller.
    public func stop() async {
        guard isRunning else { return }

        pipelineTask?.cancel()
        pipelineTask = nil
        
        keepAliveTask?.cancel()
        keepAliveTask = nil

        await capture.stop()
        await controller?.disconnect()
        controller = nil
        fluid.reset()

        isRunning    = false
        currentFPS   = 0
        latencyMs    = 0
        gpuMs        = 0

        HaloLogger.app.info("AmbientPipeline: stopped.")
    }

    /// Updates live pipeline settings without restarting.
    public func updateSettings(_ settings: HaloSyncSettings) {
        HaloLogger.app.info("AmbientPipeline: Applying new settings. Brightness: \(settings.brightness), Ambient: \(settings.ambientStrength), Smoothness: \(settings.smoothness)")
        _currentBrightness = settings.brightness
        
        var pSettings = ProcessingSettings.from(
            mode: settings.activeMode,
            brightness: settings.brightness,
            ambientStrength: settings.ambientStrength
        )
        pSettings.samplingDepth = settings.samplingDepth
        pSettings.blackBarDetection = true
        pSettings.gamma = settings.gamma
        _currentProcessingSettings = pSettings
        
        var fluidConfig = FluidEngine.Configuration()
        fluidConfig.baseSmoothing = settings.smoothness
        fluid.update(configuration: fluidConfig)
    }

    // MARK: - Private

    private var _currentBrightness: Float = 0.8
    private var _currentProcessingSettings = ProcessingSettings()

    nonisolated private func processFrame(
        frame:              CaptureFrame,
        layout:             LEDZoneLayout,
        processingSettings: ProcessingSettings,
        brightness:         Float,
        controller:         WLEDUDPController,
        metal:              MetalProcessor?,
        fluid:              FluidEngine,
        diagnostics:        DiagnosticsService
    ) async {
        let frameStart = ContinuousClock.now

        // --- GPU: Zone Sampling ---
        let gpuStart = ContinuousClock.now
        let rawColors: [LEDColor]
        if let metal {
            do {
                rawColors = try metal.process(
                    pixelBuffer: frame.pixelBuffer,
                    settings:    processingSettings,
                    layout:      layout
                )
            } catch {
                HaloLogger.metal.warning("Metal processing failed: \(error) — skipping frame")
                return
            }
        } else {
            // Fallback: solid color if Metal is unavailable.
            rawColors = Array(repeating: LEDColor(red: 0.1, green: 0.1, blue: 0.3), count: layout.totalCount)
        }

        let gpuElapsed = gpuStart.duration(to: .now)
        let gpuMilliseconds = Double(gpuElapsed.components.attoseconds) / 1e15
            + Double(gpuElapsed.components.seconds) * 1000

        // --- CPU: Fluid Engine Smoothing ---
        let rawFrame = LEDFrame(
            colors:    rawColors.map { $0.scaled(by: brightness) },
            timestamp: frame.timestamp,
            source:    .capture
        )
        let smoothedFrame = fluid.smooth(frame: rawFrame)

        // --- Network: Send to controller ---
        do {
            try await controller.send(frame: smoothedFrame)
        } catch {
            HaloLogger.network.warning("Failed to send frame: \(error)")
        }

        let totalElapsed = frameStart.duration(to: .now)
        let totalMs = Double(totalElapsed.components.attoseconds) / 1e15
            + Double(totalElapsed.components.seconds) * 1000

        // --- Diagnostics update (on main actor) ---
        await MainActor.run {
            self.currentFPS = frame.fps
            self.gpuMs      = gpuMilliseconds
            self.latencyMs  = totalMs
            self.diagnostics.record(fps: frame.fps, captureLatencyMs: totalMs, gpuMs: gpuMilliseconds, networkMs: 0)
            
            self.lastSentFrame = smoothedFrame
            self.lastFrameTime = .now
            
            self._frameCount += 1
            if self._frameCount % 60 == 0 {
                let firstColor = rawFrame.colors.first ?? .black
                HaloLogger.app.debug("Pipeline live stats — Brightness: \(brightness), Smoothness: \(self.fluid.currentSmoothingFactor), LED[0]: (\(firstColor.red), \(firstColor.green), \(firstColor.blue))")
            }
        }
    }
    
    private var _frameCount: Int = 0
    private var lastSentFrame: LEDFrame?
    private var lastFrameTime: ContinuousClock.Instant = .now
}
