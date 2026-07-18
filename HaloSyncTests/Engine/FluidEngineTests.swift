// HaloSync — HaloSyncTests/Engine/FluidEngineTests.swift
// Unit tests for FluidEngine adaptive smoothing.

import XCTest
@testable import HaloSync

final class FluidEngineTests: XCTestCase {

    private func makeEngine(smoothness: Float = 0.5, motionSensitivity: Float = 1.2) -> FluidEngine {
        var config = FluidEngine.Configuration()
        config.baseSmoothing = smoothness
        config.motionSensitivity = motionSensitivity
        return FluidEngine(configuration: config)
    }

    // MARK: - First Frame Pass-Through

    func testFirstFramePassesThrough() {
        let engine = makeEngine()
        let input = LEDFrame(colors: [.red, .green, .blue], source: .capture)
        let output = engine.smooth(frame: input)
        XCTAssertEqual(output.colors, input.colors)
    }

    // MARK: - Smoothing Applied

    func testSmoothingBlendsBetweenFrames() {
        let engine = makeEngine(smoothness: 0.5)
        // Seed with black frame.
        _ = engine.smooth(frame: .black(count: 1))
        // Now submit white frame — should blend toward white.
        let white = LEDFrame(colors: [.white], source: .capture)
        let result = engine.smooth(frame: white)
        // With motion = max (black → white), smoothing = near minimum.
        // Result should be mostly white.
        XCTAssertGreaterThan(result.colors[0].red, 0.5)
    }

    // MARK: - Reset

    func testResetClearsPreviousFrame() {
        let engine = makeEngine()
        _ = engine.smooth(frame: .black(count: 3))
        engine.reset()
        let white = LEDFrame(colors: Array(repeating: .white, count: 3), source: .capture)
        let result = engine.smooth(frame: white) // Should pass through after reset.
        XCTAssertEqual(result.colors[0], LEDColor.white)
    }

    // MARK: - Motion Score

    func testHighMotionReducesSmoothing() {
        let engine = makeEngine(smoothness: 0.8)
        _ = engine.smooth(frame: .black(count: 10))
        let white = LEDFrame(colors: Array(repeating: .white, count: 10), source: .capture)
        _ = engine.smooth(frame: white)
        // High motion (black→white) should reduce smoothing well below 0.8.
        XCTAssertLessThan(engine.currentSmoothingFactor, 0.6)
    }

    func testZeroMotionKeepsHighSmoothing() {
        let engine = makeEngine(smoothness: 0.8)
        let frame = LEDFrame(colors: Array(repeating: LEDColor(red: 0.5, green: 0.5, blue: 0.5), count: 10), source: .capture)
        _ = engine.smooth(frame: frame)
        _ = engine.smooth(frame: frame) // Identical frame = zero motion.
        XCTAssertGreaterThan(engine.currentSmoothingFactor, 0.75)
    }

    // MARK: - LED Count Mismatch

    func testLEDCountMismatchResetsSmoothing() {
        let engine = makeEngine()
        _ = engine.smooth(frame: .black(count: 5))
        let differentCount = LEDFrame(colors: Array(repeating: .white, count: 10), source: .capture)
        let result = engine.smooth(frame: differentCount)
        // Mismatch → pass through.
        XCTAssertEqual(result.colors.count, 10)
        XCTAssertEqual(result.colors[0], .white)
    }
}
