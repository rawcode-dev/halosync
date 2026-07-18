// HaloSync — Effects/EffectsEngine.swift
// Manages the active effect, drives the animation timer, and outputs LEDFrames.

import Foundation

// MARK: - EffectsEngine

/// Drives the active effect at the target FPS and publishes LEDFrame output.
/// When mode == .effects, the FrameOrchestrator routes output from here
/// instead of from the MetalProcessor.
@MainActor
public final class EffectsEngine: ObservableObject {

    // MARK: - All Effects (registry)

    public static let allEffects: [any AmbientEffectProtocol] = [
        RainbowEffect(),
        AuroraEffect(),
        OceanEffect(),
        FireEffect(),
        PulseEffect(),
        BreathingEffect(),
        StaticEffect(),
        ColorCycleEffect(),
    ]

    // MARK: - Published State

    @Published public private(set) var activeEffect: (any AmbientEffectProtocol)?
    @Published public private(set) var isRunning: Bool = false

    // MARK: - Properties

    public var onFrame: ((LEDFrame) -> Void)?

    private var ledCount: Int = 60
    private var brightness: Float = 0.80
    private var targetFPS: Double = 60
    private var animationTask: Task<Void, Never>?
    private let startTime: ContinuousClock.Instant = .now

    // MARK: - Public API

    /// Sets the active effect by ID.
    public func activate(effectID: String, ledCount: Int, brightness: Float) {
        let effect = Self.allEffects.first { $0.id == effectID }
        self.activeEffect = effect
        self.ledCount = ledCount
        self.brightness = brightness
    }

    /// Starts the animation loop.
    public func start() {
        guard activeEffect != nil else { return }
        isRunning = true
        animationTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                let interval = 1.0 / (self?.targetFPS ?? 60)
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    /// Stops the animation loop.
    public func stop() {
        animationTask?.cancel()
        isRunning = false
    }

    /// Updates brightness (called live from the slider).
    public func update(brightness: Float) {
        self.brightness = brightness
    }

    // MARK: - Private

    @MainActor
    private func tick() async {
        guard let effect = activeEffect else { return }
        let elapsed = startTime.duration(to: .now)
        let time = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) * 1e-18
        let frame = effect.next(ledCount: ledCount, time: time, brightness: brightness)
        onFrame?(frame)
    }
}
