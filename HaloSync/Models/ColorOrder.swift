// HaloSync — Models/ColorOrder.swift
// Defines byte ordering for LED strip types.
// Most common are RGB and GRB (WS2812B default).

import Foundation

/// LED color byte order for protocol encoding.
public enum ColorOrder: String, Codable, CaseIterable, Sendable {
    case rgb = "RGB"
    case grb = "GRB"
    case bgr = "BGR"
    case rbg = "RBG"

    public var displayName: String { rawValue }
}
