// HaloSync — Controller/LEDControllerProtocol.swift
// The core abstraction for any LED controller (WLED, Pixylights, Govee, etc.)
// Adding a new controller type = implement this protocol. Zero other changes needed.

import Foundation

// MARK: - LEDControllerError

public enum LEDControllerError: Error, LocalizedError {
    case notConnected
    case sendFailed(underlying: Error)
    case invalidLEDCount(got: Int, expected: Int)
    case timeout
    case protocolError(String)

    public var errorDescription: String? {
        switch self {
        case .notConnected:                    return "Controller is not connected."
        case .sendFailed(let err):             return "Failed to send frame: \(err.localizedDescription)"
        case .invalidLEDCount(let g, let e):   return "LED count mismatch: got \(g), expected \(e)."
        case .timeout:                         return "Controller did not respond in time."
        case .protocolError(let msg):          return "Protocol error: \(msg)"
        }
    }
}

// MARK: - LEDControllerProtocol

/// Abstraction over any LED controller device.
/// All methods are async and can be called from any actor context.
public protocol LEDControllerProtocol: AnyObject, Sendable {

    /// Stable identity for this controller (survives IP changes).
    var deviceInfo: DeviceInfo { get async }

    /// Whether the controller is currently reachable.
    var isConnected: Bool { get async }

    /// Connects to the controller at the given address.
    func connect(to address: String, port: UInt16) async throws

    /// Disconnects and releases all network resources.
    func disconnect() async

    /// Sends a complete LED frame to the controller.
    func send(frame: LEDFrame) async throws

    /// Sends a ping and returns the round-trip time.
    func ping() async throws -> Duration
}

// MARK: - LEDOutputProtocol

/// Encodes an `LEDFrame` into raw bytes for a specific wire protocol.
/// Stateless and Sendable — can be shared across actors.
public protocol LEDOutputProtocol: Sendable {
    /// The name of this protocol (for UI display).
    var name: String { get }

    /// Default UDP/TCP port.
    var defaultPort: UInt16 { get }

    /// Encodes a frame into raw network bytes.
    /// - Parameters:
    ///   - frame: The frame to encode
    ///   - brightness: Global brightness scale (0-1)
    ///   - colorOrder: The expected wire color order
    ///   - sequenceNumber: The sequence number (1-15), or 0 for stateless
    func encode(frame: LEDFrame, brightness: Float, colorOrder: ColorOrder, sequenceNumber: UInt8) -> Data
}
