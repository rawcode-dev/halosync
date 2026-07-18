// HaloSync — Models/LEDColor.swift
// Fundamental value type representing a single LED's color output.
// Stored as Float components for GPU compatibility and precision during blending.
// Converted to UInt8 only at the network output boundary.

import Foundation
import simd

/// A single LED's color stored in linear floating-point space.
/// - Range: 0.0 – 1.0 per channel
/// - SIMD-aligned for batch operations in FluidEngine and Metal
public struct LEDColor: Sendable, Equatable, Hashable, Codable {

    // MARK: - Stored Properties

    public var red:   Float
    public var green: Float
    public var blue:  Float

    // MARK: - Init

    @inlinable
    public init(red: Float, green: Float, blue: Float) {
        self.red   = red.clamped(to: 0...1)
        self.green = green.clamped(to: 0...1)
        self.blue  = blue.clamped(to: 0...1)
    }

    @inlinable
    public init(r: UInt8, g: UInt8, b: UInt8) {
        self.init(
            red:   Float(r) / 255,
            green: Float(g) / 255,
            blue:  Float(b) / 255
        )
    }

    // MARK: - SIMD Helpers

    /// Returns the color as a SIMD3<Float> for batch operations.
    @inlinable
    public var simd: SIMD3<Float> {
        SIMD3<Float>(red, green, blue)
    }

    @inlinable
    public init(simd: SIMD3<Float>) {
        self.init(red: simd.x, green: simd.y, blue: simd.z)
    }

    // MARK: - Byte Conversion

    /// Converts to UInt8 tuple for network packet encoding.
    @inlinable
    public func toBytes(order: ColorOrder) -> (UInt8, UInt8, UInt8) {
        let r = UInt8((red   * 255).rounded())
        let g = UInt8((green * 255).rounded())
        let b = UInt8((blue  * 255).rounded())
        switch order {
        case .rgb: return (r, g, b)
        case .grb: return (g, r, b)
        case .bgr: return (b, g, r)
        case .rbg: return (r, b, g)
        }
    }

    // MARK: - Color Math

    /// Linear interpolation toward another color.
    @inlinable
    public func lerp(to other: LEDColor, t: Float) -> LEDColor {
        LEDColor(simd: simd.lerp(to: other.simd, t: t))
    }

    /// Scales brightness by a factor in [0, 1].
    @inlinable
    public func scaled(by brightness: Float) -> LEDColor {
        LEDColor(simd: simd * brightness)
    }

    // MARK: - Statics

    public static let black = LEDColor(red: 0, green: 0, blue: 0)
    public static let white = LEDColor(red: 1, green: 1, blue: 1)
    public static let red   = LEDColor(red: 1, green: 0, blue: 0)
    public static let green = LEDColor(red: 0, green: 1, blue: 0)
    public static let blue  = LEDColor(red: 0, green: 0, blue: 1)
}

// MARK: - Float clamped helper

extension Float {
    @inlinable
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - SIMD3 lerp helper

extension SIMD3<Float> {
    @inlinable
    func lerp(to other: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        self + (other - self) * t
    }
}
