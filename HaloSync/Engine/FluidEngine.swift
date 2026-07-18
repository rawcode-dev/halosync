// HaloSync — Engine/FluidEngine.swift
// The signature feature of HaloSync.
//
// Implements motion-aware adaptive smoothing:
//   • High motion (gaming, action) → fast response, low smoothing
//   • Low motion (desktop, reading) → silky smooth, slow transitions
//
// The algorithm is intentionally simple, predictable, and tunable.
// It runs on CPU (it's just LERP + one sum) — the GPU handles the heavy work.

import Foundation

// MARK: - FluidEngine

/// Applies motion-aware adaptive smoothing to LED frame data.
/// Stateful: holds the previous frame for LERP computation.
/// Thread-isolated: must be used from a single actor/task.
public final class FluidEngine: Sendable {

    // MARK: - Configuration

    public struct Configuration: Sendable {
        /// User-facing smoothness (0.0 = instant, 1.0 = maximum).
        public var baseSmoothing: Float = 0.55

        /// How strongly detected motion reduces smoothing.
        /// Higher = more reactive to fast scenes.
        public var motionSensitivity: Float = 1.2

        /// Minimum smoothing even at maximum motion (prevents judder).
        public var minimumSmoothing: Float = 0.05

        /// Maximum smoothing even at zero motion.
        public var maximumSmoothing: Float = 0.95

        public init() {}
    }

    // MARK: - State

    // Using a class-wrapped state to allow mutation from nonisolated context.
    private let state: _State

    private final class _State: @unchecked Sendable {
        var previousFrame: [LEDColor] = []
        var currentSmoothing: Float = 0.55
        var lastMotionScore: Float = 0
        var configuration: Configuration = .init()
    }

    // MARK: - Init

    public init(configuration: Configuration = .init()) {
        self.state = _State()
        self.state.configuration = configuration
        self.state.currentSmoothing = configuration.baseSmoothing
    }

    // MARK: - Public API

    /// Updates the engine configuration (e.g. when user changes smoothness slider).
    public func update(configuration: Configuration) {
        state.configuration = configuration
    }

    /// Applies adaptive smoothing to a raw frame.
    /// - Parameters:
    ///   - frame: The new raw LED frame from the Metal processor.
    /// - Returns: A smoothed frame ready for network output.
    public func smooth(frame: LEDFrame) -> LEDFrame {
        let config = state.configuration
        let newColors = frame.colors

        // If no previous frame, pass through directly.
        guard !state.previousFrame.isEmpty,
              state.previousFrame.count == newColors.count else {
            state.previousFrame = newColors
            return frame
        }

        let prev = state.previousFrame

        // 1. Compute motion score: normalized aggregate per-LED delta.
        let motionScore = computeMotionScore(prev: prev, next: newColors)
        state.lastMotionScore = motionScore

        // 2. Compute adaptive smoothing factor.
        //    High motion → lower smoothing → faster response.
        let rawSmoothing = config.baseSmoothing - (motionScore * config.motionSensitivity)
        let adaptiveFactor = max(config.minimumSmoothing, min(config.maximumSmoothing, rawSmoothing))
        state.currentSmoothing = adaptiveFactor

        // 3. LERP: output[i] = lerp(prev[i], new[i], 1 - smoothing)
        //    When smoothing = 0.9 → 10% toward new (very slow)
        //    When smoothing = 0.05 → 95% toward new (nearly instant)
        let blendFactor = 1.0 - adaptiveFactor
        let smoothed = zip(prev, newColors).map { old, new in
            old.lerp(to: new, t: blendFactor)
        }

        state.previousFrame = smoothed

        return LEDFrame(
            colors:    smoothed,
            timestamp: frame.timestamp,
            source:    frame.source
        )
    }

    /// Resets the internal state (e.g. when switching displays or stopping).
    public func reset() {
        state.previousFrame = []
        state.currentSmoothing = state.configuration.baseSmoothing
        state.lastMotionScore = 0
    }

    /// Current adaptive smoothing factor (for diagnostics display).
    public var currentSmoothingFactor: Float { state.currentSmoothing }

    /// Current motion score (for diagnostics display).
    public var currentMotionScore: Float { state.lastMotionScore }

    // MARK: - Private

    /// Computes a normalized motion score in [0, 1].
    /// 0 = no motion, 1 = maximum possible motion.
    private func computeMotionScore(prev: [LEDColor], next: [LEDColor]) -> Float {
        guard !prev.isEmpty else { return 0 }
        var totalDelta: Float = 0
        for i in 0..<prev.count {
            let p = prev[i]
            let n = next[i]
            totalDelta += abs(p.red   - n.red)
                        + abs(p.green - n.green)
                        + abs(p.blue  - n.blue)
        }
        // Maximum possible delta per LED = 3.0 (R+G+B all flipping 0→1)
        let maxPossible = Float(prev.count) * 3.0
        return min(totalDelta / maxPossible, 1.0)
    }
}
