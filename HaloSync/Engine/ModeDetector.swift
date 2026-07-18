// HaloSync — Engine/ModeDetector.swift
// Automatically detects the ambient mode based on screen motion analysis.
// Gaming → high/sustained motion. Movie → medium motion + dark background.
// Desktop → low motion. The detection is advisory — user always wins.

import Foundation

// MARK: - ModeDetector

/// Analyzes recent motion history to suggest an appropriate AmbientMode.
/// The user's explicit mode selection always takes priority over auto-detection.
public final class ModeDetector: Sendable {

    // MARK: - Config

    public struct Configuration: Sendable {
        /// Number of frames to average for mode detection.
        public var windowSize: Int = 30

        /// Motion score above which "Gaming" is suggested.
        public var gamingThreshold: Float = 0.45

        /// Motion score above which "Movie" is suggested.
        public var movieThreshold: Float = 0.15

        /// Motion score below which "Desktop/Reading" is suggested.
        public var desktopThreshold: Float = 0.05

        public init() {}
    }

    // MARK: - State

    private let state: _State
    private final class _State: @unchecked Sendable {
        var motionHistory: [Float] = []
        var configuration: Configuration = .init()
    }

    // MARK: - Init

    public init(configuration: Configuration = .init()) {
        self.state = _State()
        self.state.configuration = configuration
    }

    // MARK: - Public API

    /// Records a new motion score sample.
    public func record(motionScore: Float) {
        state.motionHistory.append(motionScore)
        if state.motionHistory.count > state.configuration.windowSize {
            state.motionHistory.removeFirst()
        }
    }

    /// Returns the suggested mode based on recent motion history.
    public func suggestedMode() -> AmbientMode? {
        guard state.motionHistory.count >= 5 else { return nil }
        let avg = state.motionHistory.reduce(0, +) / Float(state.motionHistory.count)
        let config = state.configuration

        switch avg {
        case config.gamingThreshold...:   return .gaming
        case config.movieThreshold..<config.gamingThreshold: return .movie
        case ..<config.desktopThreshold:  return .desktop
        default:                          return .ambient
        }
    }

    /// Resets the detection history.
    public func reset() {
        state.motionHistory.removeAll()
    }
}
