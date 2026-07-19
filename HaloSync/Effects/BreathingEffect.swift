// HaloSync — Effects/BreathingEffect.swift
// Smooth breathing (sine-wave pulse) on a single configurable color.

import Foundation

/// Breathing effect — pulses all LEDs in/out on a sine wave.
public struct BreathingEffect: AmbientEffectProtocol {
    public let id = "com.halosync.effect.breathing"
    public let name = "Breathing"
    public let symbolName = "wind"
    
    public var wledHardwareEffect: WLEDHardwareEffect {
        WLEDHardwareEffect(fxID: 2, speed: 64, usesSolidColor: true)
    }

    /// The color to breathe. Default: warm white.
    public var color: LEDColor = LEDColor(red: 0.1, green: 0.8, blue: 0.9)

    /// Breaths per minute (8 = default relaxed rate).
    public var bpm: Float = 8

    public func next(ledCount: Int, time: Double, brightness: Float) -> LEDFrame {
        let period = 60.0 / Double(bpm)
        let phase  = (time / period).truncatingRemainder(dividingBy: 1.0)
        // Smooth sine: peaks at top, dips to near-zero.
        let sine   = Float((1.0 - cos(phase * .pi * 2)) / 2.0)
        let scale  = sine * brightness
        let c      = color.scaled(by: scale)
        return LEDFrame(colors: Array(repeating: c, count: ledCount), source: .effect)
    }
}
