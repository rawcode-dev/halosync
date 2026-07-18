// HaloSync — Capture/SCKCaptureEngine.swift
// Real ScreenCaptureKit screen capture engine.
// Grabs display frames at the display's native refresh rate and emits CaptureFrames.
//
// Requirements:
//   - macOS 14+
//   - com.apple.security.screen-recording entitlement
//   - User permission granted via PermissionHandler

import Foundation
import ScreenCaptureKit
import CoreGraphics
import CoreVideo

// MARK: - SCKCaptureEngine

/// Production capture engine backed by ScreenCaptureKit.
/// Streams pixel buffers at the display's native refresh rate via AsyncStream.
@MainActor
public final class SCKCaptureEngine: NSObject, CaptureEngineProtocol {

    // MARK: - CaptureEngineProtocol

    public private(set) var display: DisplayInfo?
    public private(set) var isRunning: Bool = false

    // MARK: - Private State

    private var stream: SCStream?
    private let state = StreamState()

    private final class StreamState: @unchecked Sendable {
        private let lock = NSLock()
        var continuation: AsyncStream<CaptureFrame>.Continuation?
        var lastFPSTime: ContinuousClock.Instant = .now

        func setContinuation(_ cont: AsyncStream<CaptureFrame>.Continuation?) {
            lock.lock()
            defer { lock.unlock() }
            continuation = cont
        }

        func handleFrame(_ pixelBuffer: CVPixelBuffer) {
            let now = ContinuousClock.now
            let size = CGSize(
                width:  CVPixelBufferGetWidth(pixelBuffer),
                height: CVPixelBufferGetHeight(pixelBuffer)
            )

            lock.lock()
            let elapsed = lastFPSTime.duration(to: now)
            lastFPSTime = now
            let cont = continuation
            lock.unlock()

            let elapsedSecs = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            let fps = elapsedSecs > 0 ? 1.0 / elapsedSecs : 60.0

            let frame = CaptureFrame(
                pixelBuffer: pixelBuffer,
                timestamp:   now,
                displaySize: size,
                fps:         min(max(fps, 1), 200)
            )

            cont?.yield(frame)
        }
    }

    // MARK: - Public API

    public func start(display: DisplayInfo) async throws -> AsyncStream<CaptureFrame> {
        guard !isRunning else { throw CaptureError.alreadyRunning }

        self.display = display

        // 1. Get the SCDisplay matching the displayID.
        let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let scDisplay = availableContent.displays.first(where: { $0.displayID == display.displayID }) else {
            throw CaptureError.displayNotFound(uuid: display.uuid)
        }

        // 2. Build stream config — request 60fps, full resolution.
        let config = SCStreamConfiguration()
        config.width  = Int(display.resolution.width)
        config.height = Int(display.resolution.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.pixelFormat           = kCVPixelFormatType_32BGRA
        config.showsCursor           = false
        config.capturesAudio         = false

        // 3. Build content filter — capture entire display.
        let filter = SCContentFilter(display: scDisplay, excludingApplications: [], exceptingWindows: [])

        // 4. Create the async stream for frames.
        let (stream, continuation) = AsyncStream<CaptureFrame>.makeStream(
            bufferingPolicy: .bufferingNewest(3)
        )
        state.setContinuation(continuation)

        // 5. Create and start the SCStream.
        let scStream = SCStream(filter: filter, configuration: config, delegate: nil)
        try scStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
        try await scStream.startCapture()

        self.stream    = scStream
        self.isRunning = true

        HaloLogger.capture.info("Capture started on display: \(display.name)")

        return stream
    }

    public func stop() async {
        guard isRunning else { return }
        do {
            try await stream?.stopCapture()
        } catch {
            HaloLogger.capture.warning("Error stopping capture: \(error)")
        }
        stream = nil
        state.setContinuation(nil)
        isRunning = false
        HaloLogger.capture.info("Capture stopped.")
    }
}

// MARK: - SCStreamOutput

extension SCKCaptureEngine: SCStreamOutput {
    nonisolated public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        state.handleFrame(pixelBuffer)
    }
}
