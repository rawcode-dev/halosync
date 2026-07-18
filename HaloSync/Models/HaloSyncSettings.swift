// HaloSync — Models/HaloSyncSettings.swift
// Single source of truth for all persistent user preferences.
// Persisted via UserDefaults (Codable JSON encoding).
// Exposes @Observable for SwiftUI binding — wrapped by AppViewModel.

import Foundation

/// All persistent user preferences for HaloSync.
/// Uses a flat structure for clarity — nesting only where semantically justified.
public struct HaloSyncSettings: Codable, Sendable, Equatable {

    // MARK: - Basic Controls

    /// Master brightness multiplier (0.0 – 1.0).
    public var brightness: Float = 0.80

    /// Fluid engine base smoothness (0.0 = instant, 1.0 = maximum smoothness).
    public var smoothness: Float = 0.55

    /// How strongly ambient colors map to full saturation (0.0 – 1.0).
    public var ambientStrength: Float = 0.70

    // MARK: - Active Mode

    public var activeMode: AmbientMode = .ambient
    
    /// The currently selected lighting effect ID (used when activeMode == .effects)
    public var activeEffectID: String? = nil

    // MARK: - Startup

    public var launchAtLogin: Bool = false
    public var startMinimized: Bool = false
    public var autoReconnect: Bool = true

    // MARK: - Display

    /// UUID of the last selected display (survives reboots).
    public var selectedDisplayUUID: String? = nil

    // MARK: - Controller

    /// Last known controller IP address (fallback if mDNS fails).
    public var lastKnownControllerAddress: String? = nil

    /// Active output protocol.
    public var activeProtocol: ControllerProtocol = .ddp

    // MARK: - Advanced (hidden in UI by default)

    /// Sampling depth from screen edge in logical pixels.
    public var samplingDepth: Int = 3

    /// Gamma correction value.
    public var gamma: Float = 2.2

    /// LED color byte order.
    public var colorOrder: ColorOrder = .rgb

    /// LED layout rotation (0 = default, 1 = 90°, 2 = 180°, 3 = 270°).
    public var rotation: Int = 0

    /// White balance offsets (R, G, B) — neutral = (1.0, 1.0, 1.0).
    public var whiteBalanceR: Float = 1.0
    public var whiteBalanceG: Float = 1.0
    public var whiteBalanceB: Float = 1.0

    /// UDP port override.
    public var udpPort: UInt16 = 4048
    
    // MARK: - Layout
    
    /// User-configured mapping geometry.
    public var layout: CustomLayout = .init()
    
    /// True if the hardware layout test mode is overriding the pipeline.
    public var isLayoutTestActive: Bool = false
    
    /// True if the live screen preview is shown in the Layout tab.
    public var showLivePreview: Bool = true
    
    /// Luminance threshold below which a region is classified as "black bar".
    public var blackBarThreshold: Float = 0.02
    
    /// True to dynamically ignore black letterbox/pillarbox bars.
    public var blackBarDetection: Bool = true
    
    // Manual crop percentages (0.0 to 100.0)
    public var cropTop: Float = 0.0
    public var cropBottom: Float = 0.0
    public var cropLeft: Float = 0.0
    public var cropRight: Float = 0.0

    // MARK: - Active Profile

    /// UUID of the active profile. nil = default (no profile).
    public var activeProfileID: UUID? = nil

    // MARK: - Init

    public init() {}
}

// MARK: - UserDefaults Integration

extension HaloSyncSettings {
    private static let key = "com.halosync.settings.v1"

    /// Loads settings from UserDefaults, falling back to defaults.
    public static func load() -> HaloSyncSettings {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let settings = try? JSONDecoder().decode(HaloSyncSettings.self, from: data)
        else {
            return HaloSyncSettings()
        }
        return settings
    }

    /// Persists settings to UserDefaults.
    public func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
