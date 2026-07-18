// HaloSync — Models/AmbientMode.swift
// Defines the operating modes of the ambient lighting system.
// Each mode carries default processing parameters so the system
// "just works" when the user selects a mode.

import Foundation

/// The current operating mode of HaloSync.
public enum AmbientMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case ambient    = "Ambient"
    case movie      = "Movie"
    case gaming     = "Gaming"
    case desktop    = "Desktop"
    case reading    = "Reading"
    case music      = "Music"
    case effects    = "Effects"
    case night      = "Night"
    case custom     = "Custom"

    public var id: String { rawValue }

    /// Human-readable display name.
    public var displayName: String { rawValue }

    /// SF Symbol icon name for this mode.
    public var symbolName: String {
        switch self {
        case .ambient:  return "sparkles"
        case .movie:    return "film.fill"
        case .gaming:   return "gamecontroller.fill"
        case .desktop:  return "desktopcomputer"
        case .reading:  return "book.fill"
        case .music:    return "music.note"
        case .effects:  return "wand.and.stars"
        case .night:    return "moon.fill"
        case .custom:   return "slider.horizontal.3"
        }
    }

    /// Intelligent default parameters for each mode.
    /// These are the "just works" values — users rarely need to change them.
    public var defaultParameters: ModeParameters {
        switch self {
        case .ambient:
            return ModeParameters(brightness: 0.80, smoothness: 0.55, ambientStrength: 0.70, targetFPS: 60)
        case .movie:
            return ModeParameters(brightness: 0.85, smoothness: 0.70, ambientStrength: 0.85, targetFPS: 60)
        case .gaming:
            return ModeParameters(brightness: 1.00, smoothness: 0.20, ambientStrength: 0.90, targetFPS: 120)
        case .desktop:
            return ModeParameters(brightness: 0.60, smoothness: 0.80, ambientStrength: 0.50, targetFPS: 30)
        case .reading:
            return ModeParameters(brightness: 0.40, smoothness: 0.95, ambientStrength: 0.30, targetFPS: 10)
        case .music:
            return ModeParameters(brightness: 0.90, smoothness: 0.10, ambientStrength: 0.80, targetFPS: 60)
        case .effects:
            return ModeParameters(brightness: 0.80, smoothness: 0.30, ambientStrength: 1.00, targetFPS: 60)
        case .night:
            return ModeParameters(brightness: 0.15, smoothness: 0.90, ambientStrength: 0.20, targetFPS: 10)
        case .custom:
            return ModeParameters(brightness: 0.80, smoothness: 0.50, ambientStrength: 0.80, targetFPS: 60)
        }
    }
}

// MARK: - ModeParameters

/// The set of processing parameters associated with an ambient mode.
public struct ModeParameters: Sendable, Equatable, Codable {
    public var brightness:      Float   // 0.0 – 1.0
    public var smoothness:      Float   // 0.0 – 1.0 (0 = instant, 1 = very slow)
    public var ambientStrength: Float   // 0.0 – 1.0
    public var targetFPS:       Int     // Desired update frequency

    public init(brightness: Float, smoothness: Float, ambientStrength: Float, targetFPS: Int) {
        self.brightness      = brightness
        self.smoothness      = smoothness
        self.ambientStrength = ambientStrength
        self.targetFPS       = targetFPS
    }
}
