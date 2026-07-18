// HaloSync — Effects/ColorCycleEffect.swift
// Smoothly cycles all LEDs through the full hue spectrum in unison.

import Foundation

/// Color Cycle effect — all LEDs share the same hue, cycling through the spectrum.
public struct ColorCycleEffect: AmbientEffectProtocol {
    public let id = "com.halosync.effect.colorcycle"
    public let name = "Color Cycle"
    public let symbolName = "circle.hexagongrid.fill"

    /// Cycle speed (full cycle duration in seconds at 1.0).
    public var speed: Float = 0.1
    public var saturation: Float = 1.0

    public func next(ledCount: Int, time: Double, brightness: Float) -> LEDFrame {
        guard ledCount > 0 else { return .black(count: 0) }
        let hue = (Float(time) * speed).truncatingRemainder(dividingBy: 1.0)
        let c = LEDColor(hsb: hue, saturation: saturation, brightness: brightness)
        return LEDFrame(colors: Array(repeating: c, count: ledCount), source: .effect)
    }
}
