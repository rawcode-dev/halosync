// HaloSync — Effects/AmbientEffectProtocol.swift
// Contract for all ambient lighting effects.
// Effects are stateless value types (or lightweight actors) that generate LEDFrames.

import Foundation

/// Represents the hardware configuration for an effect on a WLED controller.
public struct WLEDHardwareEffect: Sendable {
    public let fxID: Int
    public let speed: Int?
    public let intensity: Int?
    public let paletteID: Int?
    public let usesSolidColor: Bool
    
    public init(fxID: Int, speed: Int? = nil, intensity: Int? = nil, paletteID: Int? = nil, usesSolidColor: Bool = false) {
        self.fxID = fxID
        self.speed = speed
        self.intensity = intensity
        self.paletteID = paletteID
        self.usesSolidColor = usesSolidColor
    }
}

/// A self-contained ambient lighting effect.
/// Effects are called once per frame tick and must be deterministic given the same `time`.
public protocol AmbientEffectProtocol: Sendable {
    /// Unique identifier (used for persistence).
    var id: String { get }

    /// Human-readable display name.
    var name: String { get }

    /// SF Symbol icon.
    var symbolName: String { get }
    
    /// The corresponding hardware effect configuration for WLED.
    var wledHardwareEffect: WLEDHardwareEffect { get }

    /// Generates the next LED frame for the given parameters.
    /// - Parameters:
    ///   - ledCount: Number of LEDs to fill.
    ///   - time: Monotonic time in seconds (drives animation).
    ///   - brightness: Master brightness (0.0 – 1.0).
    /// - Returns: A complete `LEDFrame`.
    func next(ledCount: Int, time: Double, brightness: Float) -> LEDFrame
}
