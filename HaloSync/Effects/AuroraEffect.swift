// HaloSync — Effects/AuroraEffect.swift
// Slow, organic color shifting — inspired by the Northern Lights.
// Uses multi-octave noise simulation via layered sine waves.

import Foundation

/// Aurora effect — organic, slowly shifting cool-to-warm color waves.
public struct AuroraEffect: AmbientEffectProtocol {
    public let id = "com.halosync.effect.aurora"
    public let name = "Aurora"
    public let symbolName = "sparkles"
    
    public var wledHardwareEffect: WLEDHardwareEffect {
        WLEDHardwareEffect(fxID: 79, speed: 64) // Twinklefox
    }

    public var speed: Float = 0.3

    public func next(ledCount: Int, time: Double, brightness: Float) -> LEDFrame {
        guard ledCount > 0 else { return .black(count: 0) }
        let t = Float(time) * speed

        let colors = (0..<ledCount).map { i -> LEDColor in
            let x = Float(i) / Float(ledCount)
            // Layer multiple sine waves for organic movement.
            let h1 = sin(x * .pi * 2.0 + t * 0.7) * 0.5 + 0.5
            let h2 = sin(x * .pi * 4.0 - t * 0.5) * 0.5 + 0.5
            let hue = (h1 * 0.4 + h2 * 0.1 + 0.45).truncatingRemainder(dividingBy: 1.0) // Blue-green range
            let sat = Float(0.6 + sin(x * .pi + t) * 0.2)
            return LEDColor(hsb: hue, saturation: sat, brightness: brightness)
        }

        return LEDFrame(colors: colors, source: .effect)
    }
}
