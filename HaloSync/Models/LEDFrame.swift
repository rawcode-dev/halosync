// HaloSync — Models/LEDFrame.swift
// A single frame of LED data ready for network transmission.
// This is the currency that flows through the entire pipeline:
//   MetalProcessor → FluidEngine → LEDOutputService

import Foundation

/// A complete frame of per-LED color data for one update cycle.
/// Immutable and Sendable — safe to pass across actor boundaries.
public struct LEDFrame: Sendable {

    // MARK: - Properties

    /// Ordered array of colors, index 0 = LED 0 on the strip.
    public let colors: [LEDColor]

    /// Monotonic timestamp when this frame was generated.
    public let timestamp: ContinuousClock.Instant

    /// The source of this frame (capture or effect).
    public let source: FrameSource

    // MARK: - Init

    public init(
        colors: [LEDColor],
        timestamp: ContinuousClock.Instant = .now,
        source: FrameSource = .capture
    ) {
        self.colors    = colors
        self.timestamp = timestamp
        self.source    = source
    }

    // MARK: - Convenience

    /// Number of LEDs in this frame.
    public var ledCount: Int { colors.count }

    /// Creates a solid-color frame.
    public static func solid(_ color: LEDColor, count: Int) -> LEDFrame {
        LEDFrame(colors: Array(repeating: color, count: count))
    }

    /// Creates a black (off) frame.
    public static func black(count: Int) -> LEDFrame {
        solid(.black, count: count)
    }
}

// MARK: - FrameSource

/// Indicates where this frame originated.
public enum FrameSource: Sendable {
    case capture   // ScreenCaptureKit → Metal
    case effect    // EffectsEngine
    case calibration // CalibrationEngine
    case manual    // Direct user command
}
