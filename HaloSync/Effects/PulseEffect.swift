// HaloSync — Effects/PulseEffect.swift
// Single-LED pulse that travels across the strip, leaving a fading trail.

import Foundation

/// Pulse effect — a point of light travelling across the LED strip.
public struct PulseEffect: AmbientEffectProtocol {
    public let id = "com.halosync.effect.pulse"
    public let name = "Pulse"
    public let symbolName = "dot.radiowaves.left.and.right"

    public var color: LEDColor = LEDColor(red: 0.48, green: 0.38, blue: 1.0) // Brand purple
    public var speed: Float = 1.0
    public var trailLength: Float = 0.2  // As fraction of strip length.

    public func next(ledCount: Int, time: Double, brightness: Float) -> LEDFrame {
        guard ledCount > 0 else { return .black(count: 0) }
        let t = Float(time) * speed
        let head = t.truncatingRemainder(dividingBy: Float(ledCount))

        let colors = (0..<ledCount).map { i -> LEDColor in
            let dist = distanceCircular(from: Float(i), to: head, count: Float(ledCount))
            let trail = max(0, 1.0 - dist / (trailLength * Float(ledCount)))
            let scale = trail * trail * brightness  // Squared for nice falloff
            return color.scaled(by: scale)
        }

        return LEDFrame(colors: colors, source: .effect)
    }

    private func distanceCircular(from a: Float, to b: Float, count: Float) -> Float {
        let d = abs(a - b)
        return min(d, count - d)
    }
}
