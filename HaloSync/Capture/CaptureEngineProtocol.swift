// HaloSync — Capture/CaptureEngineProtocol.swift
// Protocol defining the screen capture contract.
// The real implementation uses ScreenCaptureKit.
// Tests use MockCaptureEngine.

import Foundation
import CoreGraphics
import CoreVideo

/// Errors that can occur during screen capture.
public enum CaptureError: Error, LocalizedError {
    case permissionDenied
    case displayNotFound(uuid: String)
    case streamFailed(underlying: Error)
    case alreadyRunning
    case notRunning

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:           return "Screen Recording permission is required. Please grant it in System Settings → Privacy → Screen Recording."
        case .displayNotFound(let uuid):  return "Display '\(uuid)' is no longer connected."
        case .streamFailed(let err):      return "Capture stream failed: \(err.localizedDescription)"
        case .alreadyRunning:             return "Capture is already running."
        case .notRunning:                 return "Capture is not running."
        }
    }
}

/// Contract for any screen capture source.
/// Emits `CaptureFrame`s via an `AsyncStream`.
@MainActor
public protocol CaptureEngineProtocol: AnyObject {
    /// The display this engine is capturing.
    var display: DisplayInfo? { get }

    /// Whether the capture stream is currently active.
    var isRunning: Bool { get }

    /// Starts capturing the given display.
    /// - Returns: An `AsyncStream` of captured frames.
    func start(display: DisplayInfo) async throws -> AsyncStream<CaptureFrame>

    /// Stops the capture stream.
    func stop() async
}

// MARK: - CaptureFrame

/// A single raw captured frame from the display.
/// The pixel buffer is retained until the frame is released.
public struct CaptureFrame: @unchecked Sendable {
    /// The raw pixel data (GPU-backed CVPixelBuffer or IOSurface).
    public let pixelBuffer: CVPixelBuffer

    /// The timestamp when this frame was captured (host time).
    public let timestamp: ContinuousClock.Instant

    /// The display dimensions (may differ from buffer dimensions due to scaling).
    public let displaySize: CGSize

    /// Frames per second at time of capture.
    public let fps: Double

    public init(pixelBuffer: CVPixelBuffer, timestamp: ContinuousClock.Instant, displaySize: CGSize, fps: Double) {
        self.pixelBuffer = pixelBuffer
        self.timestamp   = timestamp
        self.displaySize = displaySize
        self.fps         = fps
    }
}

extension CVPixelBuffer: @unchecked Sendable {}
