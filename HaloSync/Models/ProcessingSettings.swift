// HaloSync — Models/ProcessingSettings.swift
// Configuration bag passed into the Metal processing pipeline per frame.
// Keeps the Metal layer stateless and testable.

import Foundation

/// All tunable parameters for the GPU frame processing pipeline.
public struct ProcessingSettings: Sendable, Equatable, Codable {

    // MARK: - Sampling

    /// Depth from screen edge to sample (in logical pixels).
    /// 3px default gives good color representation without content bleed.
    public var samplingDepth: Int = 3

    /// Number of sample points per LED zone.
    /// Higher = more accurate but slightly more GPU work.
    public var samplesPerZone: Int = 16

    // MARK: - Color Correction

    /// Display gamma (standard: 2.2, HDR: 1.0).
    public var gamma: Float = 2.2

    /// White balance offsets [R, G, B] in linear space.
    public var whiteBalance: SIMD3<Float> = .one
    
    /// Wall Color Compensation offsets [R, G, B] applied to counteract physical wall color.
    public var wallCompensation: SIMD3<Float> = .one

    /// Overall brightness multiplier applied after all processing.
    public var brightness: Float = 0.80

    /// Ambient strength — blends sampled color with a boost.
    public var ambientStrength: Float = 0.70

    // MARK: - Black Bar Detection

    /// Automatically detect and ignore letterbox / pillarbox bars.
    public var blackBarDetection: Bool = true

    /// Luminance threshold below which a region is classified as "black bar".
    public var blackBarThreshold: Float = 0.02

    // MARK: - Manual Crop
    
    // Manual crop percentages (0.0 to 100.0)
    public var cropTop: Float = 0.0
    public var cropBottom: Float = 0.0
    public var cropLeft: Float = 0.0
    public var cropRight: Float = 0.0

    // MARK: - HDR

    /// Whether the source display is HDR. Adjusts tone-mapping.
    public var isHDRSource: Bool = false

    // MARK: - Output

    /// Byte ordering expected by the LED strip.
    public var colorOrder: ColorOrder = .rgb

    // MARK: - Layout & Testing
    
    /// User configured geometry mapping.
    public var layout: CustomLayout = .init()
    
    /// If true, overrides ambient colors with a static segment test pattern.
    public var isLayoutTestActive: Bool = false

    // MARK: - Init

    public init() {}

    /// Creates settings from a mode + user preferences.
    public static func from(mode: AmbientMode, brightness: Float, ambientStrength: Float, wallColor: SIMD3<Float> = .one) -> ProcessingSettings {
        var settings = ProcessingSettings()
        let params = mode.defaultParameters
        settings.brightness      = brightness
        settings.ambientStrength = ambientStrength
        
        // Calculate Wall Color Compensation (Subtractive Math)
        // We invert the user's wall color, so when the light hits the wall, the reflection equals true white.
        // We use max(x, 0.1) to avoid dividing by zero or producing astronomically bright compensates for black walls.
        settings.wallCompensation = SIMD3<Float>(
            1.0 / max(wallColor.x, 0.1),
            1.0 / max(wallColor.y, 0.1),
            1.0 / max(wallColor.z, 0.1)
        )
        // Normalize the compensation so the brightest channel remains 1.0 (prevents blowing out the brightness entirely)
        let maxComp = max(settings.wallCompensation.x, max(settings.wallCompensation.y, settings.wallCompensation.z))
        if maxComp > 0 {
            settings.wallCompensation /= maxComp
        }
        
        return settings
    }
}
