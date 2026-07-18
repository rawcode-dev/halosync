// HaloSync — Effects/OceanEffect.swift
// Deep blues and teals washing across the strip in wave patterns.

import Foundation

/// Ocean effect — cool blue/teal waves with organic movement.
public struct OceanEffect: AmbientEffectProtocol {
    public let id = "com.halosync.effect.ocean"
    public let name = "Ocean"
    public let symbolName = "water.waves"

    public var speed: Float = 0.8

    public func next(ledCount: Int, time: Double, brightness: Float) -> LEDFrame {
        guard ledCount > 0 else { return .black(count: 0) }
        let t = Float(time) * speed

        let colors = (0..<ledCount).map { i -> LEDColor in
            let x = Float(i) / Float(ledCount)
            let wave1 = sin(x * .pi * 3 + t * 1.1) * 0.5 + 0.5
            let wave2 = sin(x * .pi * 5 - t * 0.7) * 0.5 + 0.5
            let blend = (wave1 * 0.6 + wave2 * 0.4)
            // Ocean palette: deep navy → cyan → teal
            let r = blend * 0.0
            let g = blend * 0.55
            let b = blend * 1.0
            return LEDColor(
                red:   (r * brightness).clamped(to: 0...1),
                green: (g * brightness).clamped(to: 0...1),
                blue:  (b * brightness).clamped(to: 0...1)
            )
        }

        return LEDFrame(colors: colors, source: .effect)
    }
}
