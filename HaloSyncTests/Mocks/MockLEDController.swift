// HaloSync — HaloSyncTests/Mocks/MockLEDController.swift
// Test double for LEDControllerProtocol. Records all sent frames for assertion.

import Foundation
@testable import HaloSync

final class MockLEDController: LEDControllerProtocol, @unchecked Sendable {

    // MARK: - Recorded Calls

    private(set) var sentFrames: [LEDFrame] = []
    private(set) var pingCallCount: Int = 0
    private(set) var connectCallCount: Int = 0
    private(set) var disconnectCallCount: Int = 0

    // MARK: - Configurable Behavior

    var shouldThrowOnSend: Bool = false
    var mockPingLatency: Duration = .milliseconds(4)
    var mockDeviceInfo = DeviceInfo(
        name: "Mock Controller",
        address: "192.168.1.100",
        ledCount: 60,
        firmwareVersion: "0.14.4",
        connectionStatus: .connected
    )

    // MARK: - LEDControllerProtocol

    var deviceInfo: DeviceInfo { get async { mockDeviceInfo } }
    var isConnected: Bool { get async { true } }

    func connect(to address: String, port: UInt16) async throws {
        connectCallCount += 1
    }

    func disconnect() async {
        disconnectCallCount += 1
    }

    func send(frame: LEDFrame) async throws {
        if shouldThrowOnSend {
            throw LEDControllerError.notConnected
        }
        sentFrames.append(frame)
    }

    func ping() async throws -> Duration {
        pingCallCount += 1
        return mockPingLatency
    }

    // MARK: - Test Helpers

    func reset() {
        sentFrames.removeAll()
        pingCallCount = 0
        connectCallCount = 0
        disconnectCallCount = 0
    }

    var lastSentFrame: LEDFrame? { sentFrames.last }
}
