// HaloSync — Effects/FireEffect.swift
// Simulates flames — red/orange/yellow color waves flowing upward.

import Foundation

/// Fire effect — flickering warm colors with upward motion simulation.
public struct FireEffect: AmbientEffectProtocol {
    public let id = "com.halosync.effect.fire"
    public let name = "Fire"
    public let symbolName = "flame.fill"

    public var speed: Float = 1.5
    public var intensity: Float = 0.85

    public func next(ledCount: Int, time: Double, brightness: Float) -> LEDFrame {
        guard ledCount > 0 else { return .black(count: 0) }
        let t = Float(time) * speed

        let colors = (0..<ledCount).map { i -> LEDColor in
            let x = Float(i) / Float(ledCount)
            // Flame-like noise using layered sines.
            let flicker = sin(x * 18 + t * 6.7) * 0.15
                        + sin(x * 7  - t * 4.3) * 0.20
                        + 0.65
            let v = (flicker * intensity * brightness).clamped(to: 0...1)
            // Map value to fire palette: black → red → orange → yellow.
            let r = min(v * 2.0, 1.0)
            let g = max(v * 2.0 - 1.0, 0) * 0.7
            let b: Float = 0
            return LEDColor(red: r, green: g, blue: b)
        }

        return LEDFrame(colors: colors, source: .effect)
    }
}
