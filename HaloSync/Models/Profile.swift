// HaloSync — Models/Profile.swift
// A user-defined preset that remembers all ambient settings.
// Profiles are stored in UserDefaults and are importable/exportable as JSON.

import Foundation

/// A complete user profile that fully configures the ambient lighting system.
public struct Profile: Sendable, Identifiable, Equatable, Codable {

    // MARK: - Identity

    public var id: UUID
    public var name: String
    public var icon: String         // SF Symbol name
    public var colorAccent: String  // Hex color string for UI accent

    // MARK: - Core Settings

    public var brightness: Float
    public var smoothness: Float
    public var ambientStrength: Float
    public var mode: AmbientMode

    // MARK: - Hardware Binding

    /// UUID of the display this profile is bound to. nil = any display.
    public var monitorUUID: String?

    /// Stored controller address this profile targets. nil = auto-discovered.
    public var controllerAddress: String?

    // MARK: - Effect

    /// Effect ID when mode == .effects.
    public var effectID: String?

    // MARK: - Metadata

    public var isBuiltIn: Bool      // Factory profiles cannot be deleted
    public var createdAt: Date
    public var modifiedAt: Date

    // MARK: - Init

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String = "sparkles",
        colorAccent: String = "#7B61FF",
        brightness: Float = 0.80,
        smoothness: Float = 0.55,
        ambientStrength: Float = 0.70,
        mode: AmbientMode = .ambient,
        monitorUUID: String? = nil,
        controllerAddress: String? = nil,
        effectID: String? = nil,
        isBuiltIn: Bool = false,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id                = id
        self.name              = name
        self.icon              = icon
        self.colorAccent       = colorAccent
        self.brightness        = brightness
        self.smoothness        = smoothness
        self.ambientStrength   = ambientStrength
        self.mode              = mode
        self.monitorUUID       = monitorUUID
        self.controllerAddress = controllerAddress
        self.effectID          = effectID
        self.isBuiltIn         = isBuiltIn
        self.createdAt         = createdAt
        self.modifiedAt        = modifiedAt
    }

    // MARK: - Factory Profiles

    /// Built-in profiles that ship with HaloSync.
    public static var builtIns: [Profile] {
        [
            Profile(name: "Movie Night", icon: "film.fill",           colorAccent: "#E05D4B", brightness: 0.85, smoothness: 0.70, ambientStrength: 0.85, mode: .movie,   isBuiltIn: true),
            Profile(name: "Gaming",      icon: "gamecontroller.fill",  colorAccent: "#4BFF91", brightness: 1.00, smoothness: 0.20, ambientStrength: 0.90, mode: .gaming,  isBuiltIn: true),
            Profile(name: "Reading",     icon: "book.fill",            colorAccent: "#F5C842", brightness: 0.40, smoothness: 0.95, ambientStrength: 0.30, mode: .reading, isBuiltIn: true),
            Profile(name: "Night",       icon: "moon.fill",            colorAccent: "#3D5A80", brightness: 0.15, smoothness: 0.90, ambientStrength: 0.20, mode: .night,   isBuiltIn: true),
        ]
    }
}
