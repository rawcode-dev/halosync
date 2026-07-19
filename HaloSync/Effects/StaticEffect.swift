// HaloSync — Effects/StaticEffect.swift
// Fills all LEDs with a single configurable color.

import Foundation

/// Static effect — holds a solid color across all LEDs.
public struct StaticEffect: AmbientEffectProtocol {
    public let id = "com.halosync.effect.static"
    public let name = "Solid Color"
    public let symbolName = "paintpalette.fill"
    
    public var wledHardwareEffect: WLEDHardwareEffect {
        WLEDHardwareEffect(fxID: 0, usesSolidColor: true)
    }

    public var color: LEDColor = .white

    public func next(ledCount: Int, time: Double, brightness: Float) -> LEDFrame {
        let c = color.scaled(by: brightness)
        return LEDFrame(colors: Array(repeating: c, count: ledCount), source: .effect)
    }
}
