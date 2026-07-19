// HaloSync — Effects/RainbowEffect.swift
// Smooth HSB rainbow cycling across all LEDs.
// Speed and saturation are configurable.

import Foundation

/// Classic rainbow effect — cycles hue across all LEDs over time.
public struct RainbowEffect: AmbientEffectProtocol {
    public let id = "com.halosync.effect.rainbow"
    public let name = "Rainbow"
    public let symbolName = "rainbow"

    public var wledHardwareEffect: WLEDHardwareEffect {
        WLEDHardwareEffect(fxID: 9, speed: 128) // Rainbow Cycle
    }

    /// Speed multiplier (1.0 = default, 2.0 = twice as fast).
    public var speed: Float = 1.0

    /// Spread controls how many full hue cycles appear across the strip.
    public var spread: Float = 1.0

    public func next(ledCount: Int, time: Double, brightness: Float) -> LEDFrame {
        guard ledCount > 0 else { return .black(count: 0) }

        let colors = (0..<ledCount).map { i -> LEDColor in
            let hue = (Float(time) * speed * 0.2 + Float(i) / Float(ledCount) * spread).truncatingRemainder(dividingBy: 1.0)
            return LEDColor(hsb: hue, saturation: 1.0, brightness: brightness)
        }

        return LEDFrame(colors: colors, source: .effect)
    }
}

// MARK: - HSB Init for LEDColor

extension LEDColor {
    /// Creates an LEDColor from Hue/Saturation/Brightness (HSB) values.
    /// All values in [0, 1].
    public init(hsb h: Float, saturation s: Float, brightness v: Float) {
        let h6 = h * 6.0
        let i  = Int(h6) % 6
        let f  = h6 - Float(Int(h6))
        let p  = v * (1 - s)
        let q  = v * (1 - f * s)
        let t  = v * (1 - (1 - f) * s)

        switch i {
        case 0: self.init(red: v, green: t, blue: p)
        case 1: self.init(red: q, green: v, blue: p)
        case 2: self.init(red: p, green: v, blue: t)
        case 3: self.init(red: p, green: q, blue: v)
        case 4: self.init(red: t, green: p, blue: v)
        default: self.init(red: v, green: p, blue: q)
        }
    }
}
