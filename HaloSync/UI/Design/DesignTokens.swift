// HaloSync — UI/Design/DesignTokens.swift
// Single source of truth for all visual design tokens.
// Spacing, radius, animation, shadow — all defined here.
// Never hardcode values in views.

import SwiftUI

// MARK: - Spacing

public enum Spacing {
    public static let xxs: CGFloat = 2
    public static let xs:  CGFloat = 4
    public static let sm:  CGFloat = 8
    public static let md:  CGFloat = 12
    public static let lg:  CGFloat = 16
    public static let xl:  CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let xxxl: CGFloat = 48
}

// MARK: - Radius

public enum Radius {
    public static let sm:  CGFloat = 8
    public static let md:  CGFloat = 12
    public static let lg:  CGFloat = 16
    public static let xl:  CGFloat = 20
    public static let xxl: CGFloat = 28
    public static let pill: CGFloat = 999
}

// MARK: - Animation

public enum Anim {
    /// Standard snappy interaction feedback.
    public static let snap   = Animation.spring(response: 0.3, dampingFraction: 0.7)
    /// Gentle entrance animation.
    public static let gentle = Animation.spring(response: 0.5, dampingFraction: 0.8)
    /// Very slow ambient transition.
    public static let slow   = Animation.easeInOut(duration: 0.8)
    /// Micro-animation for toggles/badges.
    public static let micro  = Animation.easeOut(duration: 0.15)
}

// MARK: - Shadow

public enum Shadow {
    public static let sm  = ShadowConfig(color: .black.opacity(0.25), radius: 4,  x: 0, y: 2)
    public static let md  = ShadowConfig(color: .black.opacity(0.30), radius: 12, x: 0, y: 4)
    public static let lg  = ShadowConfig(color: .black.opacity(0.40), radius: 24, x: 0, y: 8)
    public static let glow = ShadowConfig(color: Color.haloPrimary.opacity(0.45), radius: 16, x: 0, y: 0)
}

public struct ShadowConfig: Sendable {
    public let color:  Color
    public let radius: CGFloat
    public let x:      CGFloat
    public let y:      CGFloat
}

// MARK: - Typography

public enum Typography {
    // Display
    public static let display     = Font.system(size: 32, weight: .bold, design: .rounded)
    public static let title       = Font.system(size: 22, weight: .semibold, design: .rounded)
    public static let headline    = Font.system(size: 17, weight: .semibold, design: .default)
    // Body
    public static let body        = Font.system(size: 14, weight: .regular, design: .default)
    public static let bodyMedium  = Font.system(size: 14, weight: .medium,  design: .default)
    // Caption
    public static let caption     = Font.system(size: 12, weight: .regular, design: .default)
    public static let captionMed  = Font.system(size: 12, weight: .medium,  design: .default)
    public static let micro       = Font.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit()
    // Mono
    public static let mono        = Font.system(size: 12, weight: .regular, design: .monospaced)
    public static let monoMedium  = Font.system(size: 12, weight: .medium,  design: .monospaced)
}

// MARK: - View Extension: apply shadow config

extension View {
    func haloShadow(_ config: ShadowConfig) -> some View {
        shadow(color: config.color, radius: config.radius, x: config.x, y: config.y)
    }
}
