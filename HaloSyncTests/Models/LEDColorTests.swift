// HaloSync — HaloSyncTests/Models/LEDColorTests.swift
// Unit tests for LEDColor value type.

import XCTest
@testable import HaloSync

final class LEDColorTests: XCTestCase {

    // MARK: - Init

    func testInitClampsValues() {
        let color = LEDColor(red: 1.5, green: -0.1, blue: 0.5)
        XCTAssertEqual(color.red,   1.0)
        XCTAssertEqual(color.green, 0.0)
        XCTAssertEqual(color.blue,  0.5)
    }

    func testInitFromBytes() {
        let color = LEDColor(r: 255, g: 128, b: 0)
        XCTAssertEqual(color.red,   1.0,       accuracy: 0.01)
        XCTAssertEqual(color.green, 128.0/255, accuracy: 0.01)
        XCTAssertEqual(color.blue,  0.0,       accuracy: 0.01)
    }

    // MARK: - Lerp

    func testLerpHalfway() {
        let a = LEDColor.black
        let b = LEDColor.white
        let mid = a.lerp(to: b, t: 0.5)
        XCTAssertEqual(mid.red,   0.5, accuracy: 0.001)
        XCTAssertEqual(mid.green, 0.5, accuracy: 0.001)
        XCTAssertEqual(mid.blue,  0.5, accuracy: 0.001)
    }

    func testLerpAtZeroReturnsSource() {
        let result = LEDColor.red.lerp(to: LEDColor.blue, t: 0.0)
        XCTAssertEqual(result, LEDColor.red)
    }

    func testLerpAtOneReturnsTarget() {
        let result = LEDColor.red.lerp(to: LEDColor.blue, t: 1.0)
        XCTAssertEqual(result, LEDColor.blue)
    }

    // MARK: - Scale

    func testScaleBy50Percent() {
        let color = LEDColor.white.scaled(by: 0.5)
        XCTAssertEqual(color.red,   0.5, accuracy: 0.001)
        XCTAssertEqual(color.green, 0.5, accuracy: 0.001)
        XCTAssertEqual(color.blue,  0.5, accuracy: 0.001)
    }

    // MARK: - Byte Conversion

    func testToBytesRGB() {
        let color = LEDColor(red: 1.0, green: 0.5, blue: 0.0)
        let (r, g, b) = color.toBytes(order: .rgb)
        XCTAssertEqual(r, 255)
        XCTAssertEqual(g, 128)
        XCTAssertEqual(b, 0)
    }

    func testToBytesGRB() {
        let color = LEDColor(red: 1.0, green: 0.5, blue: 0.0)
        let (c0, c1, c2) = color.toBytes(order: .grb)
        XCTAssertEqual(c0, 128) // G
        XCTAssertEqual(c1, 255) // R
        XCTAssertEqual(c2, 0)   // B
    }

    // MARK: - SIMD

    func testSIMDRoundTrip() {
        let color = LEDColor(red: 0.3, green: 0.5, blue: 0.8)
        let roundTripped = LEDColor(simd: color.simd)
        XCTAssertEqual(roundTripped.red,   color.red,   accuracy: 0.001)
        XCTAssertEqual(roundTripped.green, color.green, accuracy: 0.001)
        XCTAssertEqual(roundTripped.blue,  color.blue,  accuracy: 0.001)
    }
}
