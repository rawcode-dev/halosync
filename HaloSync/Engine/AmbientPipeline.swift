// HaloSync — Engine/AmbientPipeline.swift
// The heart of HaloSync. Wires the full pipeline:
//
//   SCKCaptureEngine → MetalProcessor → FluidEngine → WLEDUDPController
//
// Start/stop controls the entire chain atomically.
// Exposes @Published state for the UI to observe.

import Foundation
import SwiftUI
import Metal
import simd
import VideoToolbox

/// Unchecked wrapper to safely pass MTLBuffer across actor boundaries.
/// Metal objects are inherently thread-safe in Apple's frameworks.
private struct SendableMTLBuffer: @unchecked Sendable {
    let buffer: MTLBuffer
}

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
    @Published public private(set) var previewImage: CGImage?

    // MARK: - Dependencies

    private let capture:     SCKCaptureEngine
    private let metal:       MetalProcessor?
    private let fluid:       FluidEngine
    private let diagnostics: DiagnosticsService
    private let effects:     EffectsEngine

    // MARK: - Private State

    private var pipelineTask: Task<Void, Never>?
    private var controller:   WLEDUDPController?
    private var keepAliveTask: Task<Void, Never>?

    // MARK: - Init

    public init(fluid: FluidEngine, diagnostics: DiagnosticsService, effects: EffectsEngine) {
        self.capture     = SCKCaptureEngine()
        self.metal       = try? MetalProcessor()
        self.fluid       = fluid
        self.diagnostics = diagnostics
        self.effects     = effects

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

        // 2. Start capture stream if not in Effects Mode.
        var frameStream: AsyncStream<CaptureFrame>? = nil
        if settings.activeMode != .effects {
            do {
                frameStream = try await capture.start(display: display)
            } catch {
                HaloLogger.capture.error("Pipeline failed to start capture: \(error)")
                await udpController.disconnect()
                return
            }
        }

        isRunning = true

        self._currentLedCount = device.ledCount
        self.updateSettings(settings)

        // If in effects mode, we bypass screen capture and use EffectsEngine
        if settings.activeMode == .effects {
            effects.onFrame = { [weak self, weak udpController] frame in
                guard let self, let ctrl = udpController else { return }
                let order = self._currentProcessingSettings.colorOrder
                
                // Diagnostics
                Task { @MainActor in
                    self.lastSentFrame = frame
                    self.lastFrameTime = .now
                    self.diagnostics.record(fps: 60, captureLatencyMs: 0, gpuMs: 0, networkMs: 0)
                }
                
                Task {
                    try? await ctrl.send(frame: frame, colorOrder: order)
                }
            }
            if let effectID = settings.activeEffectID {
                effects.activate(effectID: effectID, ledCount: device.ledCount, brightness: settings.brightness)
            } else {
                effects.activate(effectID: "Rainbow", ledCount: device.ledCount, brightness: settings.brightness)
            }
            effects.start()
            HaloLogger.app.info("AmbientPipeline: running (Effects Mode) ✓")
            return
        }

        // 3. Run the pipeline loop in a background task.
        let ledCount = device.ledCount
        self._currentLedCount = ledCount
        
        self.updateSettings(settings)

        // Keep-alive task for static screens. WLED reverts to internal effects after 2500ms
        // of no DDP packets. If SCK drops frames because the screen is static, we must resend.
        // We poll every 500ms to ensure we stay well within the WLED timeout window.
        keepAliveTask = Task { [weak self, weak udpController] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, let ctrl = udpController else { break }
                
                let (frame, time) = (self.lastSentFrame, self.lastFrameTime)
                let currentOrder = self._currentProcessingSettings.colorOrder
                if let frame, time.duration(to: .now) >= .milliseconds(500) {
                    try? await ctrl.send(frame: frame, colorOrder: currentOrder)
                }
            }
        }

        pipelineTask = Task.detached(priority: .userInteractive) { [weak self] in
            guard let self, let stream = frameStream else { return }

            for await frame in stream {
                guard !Task.isCancelled else { break }
                let m = self.metal
                let f = self.fluid
                let d = self.diagnostics
                
                let (liveBrightness, liveSettings, liveLayoutBufferBox) = await MainActor.run {
                    (self._currentBrightness, self._currentProcessingSettings, self._currentLayoutBuffer)
                }

                // --- HARDWARE TEST BYPASS ---
                if liveSettings.isLayoutTestActive {
                    let testColors = LayoutTestGenerator.generate(layout: liveSettings.layout, totalLeds: ledCount)
                    let outFrame = LEDFrame(colors: testColors, timestamp: .now, source: .calibration)
                    try? await udpController.send(frame: outFrame, colorOrder: liveSettings.colorOrder)
                    
                    await MainActor.run {
                        self.lastSentFrame = outFrame
                        self.lastFrameTime = .now
                    }
                    continue
                }
                // -----------------------------

                await self.processFrame(
                    frame:              frame,
                    ledCount:           ledCount,
                    layoutBuffer:       liveLayoutBufferBox?.buffer,
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
        effects.stop()
        effects.onFrame = nil
        
        await controller?.disconnect()
        controller = nil
        fluid.reset()

        isRunning    = false
        currentFPS   = 0
        latencyMs    = 0
        gpuMs        = 0
        _currentLedCount = 0
        _currentLayoutBuffer = nil

        HaloLogger.app.info("AmbientPipeline: stopped.")
    }

    /// Updates live pipeline settings without restarting.
    public func updateSettings(_ settings: HaloSyncSettings) {
        HaloLogger.app.info("AmbientPipeline: Applying new settings. Brightness: \(settings.brightness), Ambient: \(settings.ambientStrength), Smoothness: \(settings.smoothness)")
        _currentBrightness = settings.brightness
        
        var pSettings = ProcessingSettings.from(
            mode: settings.activeMode,
            brightness: settings.brightness,
            ambientStrength: settings.ambientStrength,
            wallColor: settings.wallColor
        )
        pSettings.samplingDepth = settings.samplingDepth
        pSettings.blackBarDetection = settings.blackBarDetection
        pSettings.cropTop = settings.cropTop
        pSettings.cropBottom = settings.cropBottom
        pSettings.cropLeft = settings.cropLeft
        pSettings.cropRight = settings.cropRight
        pSettings.gamma = settings.gamma
        pSettings.colorOrder = settings.colorOrder
        pSettings.layout = settings.layout
        
        let wasTestActive = _currentProcessingSettings.isLayoutTestActive
        pSettings.isLayoutTestActive = settings.isLayoutTestActive
        _currentProcessingSettings = pSettings
        
        if let metal = self.metal, _currentLedCount > 0 {
            let coordinates = CoordinateMapper().map(
                layout: settings.layout,
                totalLeds: _currentLedCount,
                cropTop: Float(settings.cropTop) / 100.0,
                cropBottom: Float(settings.cropBottom) / 100.0,
                cropLeft: Float(settings.cropLeft) / 100.0,
                cropRight: Float(settings.cropRight) / 100.0
            )
            if let newBuffer = metal.makeLayoutBuffer(coordinates: coordinates) {
                _currentLayoutBuffer = SendableMTLBuffer(buffer: newBuffer)
            }
        }
        
        var fluidConfig = FluidEngine.Configuration()
        fluidConfig.baseSmoothing = settings.smoothness
        fluid.update(configuration: fluidConfig)
        
        // Kickstart the hardware test if it was just turned on, so keepAliveTask sends it instantly
        if !wasTestActive && settings.isLayoutTestActive {
            if self.controller != nil {
                let testColors = LayoutTestGenerator.generate(layout: settings.layout, totalLeds: settings.layout.totalLEDs)
                let testFrame = LEDFrame(colors: testColors, timestamp: .now, source: .calibration)
                self.lastSentFrame = testFrame
                self.lastFrameTime = .now
            }
        }
        
        // To ensure thread-safety, we rely on the screen capture or keep-alive loop to push new frames.
        // Screen capture automatically pushes frames, so it will pick up the new settings on the next frame.
    }

    // MARK: - Private

    private var _currentBrightness: Float = 0.8
    private var _currentProcessingSettings = ProcessingSettings()
    private var _currentLayoutBuffer: SendableMTLBuffer?
    private var _currentLedCount: Int = 0
    private var _lastCaptureFrame: CaptureFrame?

    nonisolated private func processFrame(
        frame:              CaptureFrame,
        ledCount:           Int,
        layoutBuffer:       MTLBuffer?,
        processingSettings: ProcessingSettings,
        brightness:         Float,
        controller:         WLEDUDPController,
        metal:              MetalProcessor?,
        fluid:              FluidEngine,
        diagnostics:        DiagnosticsService
    ) async {
        await MainActor.run {
            self._lastCaptureFrame = frame
        }
        
        let frameStart = ContinuousClock.now

        // --- GPU: Zone Sampling ---
        let gpuStart = ContinuousClock.now
        let rawColors: [LEDColor]
        if let metal, let layoutBuffer {
            do {
                rawColors = try metal.process(
                    pixelBuffer:  frame.pixelBuffer,
                    settings:     processingSettings,
                    ledCount:     ledCount,
                    layoutBuffer: layoutBuffer
                )
            } catch {
                HaloLogger.metal.warning("Metal processing failed: \(error) — skipping frame")
                return
            }
        } else {
            // Fallback: solid color if Metal is unavailable.
            rawColors = Array(repeating: LEDColor(red: 0.1, green: 0.1, blue: 0.3), count: ledCount)
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
            try await controller.send(frame: smoothedFrame, colorOrder: processingSettings.colorOrder)
        } catch {
            HaloLogger.network.warning("Failed to send frame: \(error)")
        }
        
        // --- UI: Update Preview Image (throtled to ~10fps) ---
        var newPreview: CGImage? = nil
        let currentCount = await MainActor.run { self._frameCount }
        if currentCount % 6 == 0 {
            VTCreateCGImageFromCVPixelBuffer(frame.pixelBuffer, options: nil, imageOut: &newPreview)
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
            
            if let newPreview {
                self.previewImage = newPreview
            }
            
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
