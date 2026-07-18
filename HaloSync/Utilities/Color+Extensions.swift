// HaloSync — Utilities/Color+Extensions.swift
// Helpers to bridge LEDColor ↔ SwiftUI Color and perform hex conversion.

import SwiftUI

extension Color {
    // MARK: - Hex Init

    /// Creates a Color from a hex string (e.g. "#7B61FF" or "7B61FF").
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension LEDColor {
    /// Converts LEDColor to a SwiftUI Color for preview purposes.
    var swiftUIColor: Color {
        Color(
            red:   Double(red),
            green: Double(green),
            blue:  Double(blue)
        )
    }
}

// MARK: - HaloSync Design Colors

extension Color {
    /// Primary brand purple.
    static let haloPrimary   = Color(hex: "#7B61FF")
    /// Warm accent.
    static let haloAccent    = Color(hex: "#FF6B9D")
    /// Success green.
    static let haloSuccess   = Color(hex: "#4BFF91")
    /// Warning amber.
    static let haloWarning   = Color(hex: "#F5C842")
    /// Error red.
    static let haloError     = Color(hex: "#FF5A5A")

    /// Card background (dark mode).
    static let haloCard      = Color(white: 0.12)
    /// Subtle border.
    static let haloBorder    = Color(white: 0.20)
    /// Background base.
    static let haloBackground = Color(white: 0.08)
}

// MARK: - ShapeStyle Conformances

extension ShapeStyle where Self == Color {
    public static var haloPrimary: Color { .haloPrimary }
    public static var haloAccent: Color { .haloAccent }
    public static var haloSuccess: Color { .haloSuccess }
    public static var haloWarning: Color { .haloWarning }
    public static var haloError: Color { .haloError }
    public static var haloCard: Color { .haloCard }
    public static var haloBorder: Color { .haloBorder }
    public static var haloBackground: Color { .haloBackground }
}
