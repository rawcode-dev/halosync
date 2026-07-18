// HaloSync — Models/DeviceInfo.swift
// Represents a discovered LED controller's identity and capabilities.
// Immutable snapshot — updated atomically whenever the controller is re-queried.

import Foundation

/// Immutable snapshot of a discovered LED controller's state.
public struct DeviceInfo: Sendable, Identifiable, Equatable, Codable {

    // MARK: - Identity

    public let id: UUID

    /// Human-readable name (from WLED JSON API "info.name").
    public let name: String

    /// Manufacturer or product identifier.
    public let productName: String

    // MARK: - Connectivity

    /// Current IP address (may change if DHCP reassigns).
    public let address: String

    /// UDP/TCP port used for the active protocol.
    public let port: UInt16

    /// mDNS hostname if discovered via Bonjour (e.g. "wled-abc123.local").
    public let mdnsHostname: String?

    // MARK: - Hardware

    /// Number of individually addressable LEDs.
    public let ledCount: Int

    /// Firmware version string (e.g. "0.14.4").
    public let firmwareVersion: String

    /// Active LED protocol on the controller.
    public let activeProtocol: ControllerProtocol

    // MARK: - Status

    /// Current connection state.
    public let connectionStatus: ConnectionStatus

    /// Last measured round-trip latency.
    public let latency: Duration?

    /// UTC timestamp of the last successful communication.
    public let lastSeenAt: Date

    // MARK: - Init

    public init(
        id: UUID = UUID(),
        name: String,
        productName: String = "WLED Controller",
        address: String,
        port: UInt16 = 4048,
        mdnsHostname: String? = nil,
        ledCount: Int,
        firmwareVersion: String = "Unknown",
        activeProtocol: ControllerProtocol = .ddp,
        connectionStatus: ConnectionStatus = .disconnected,
        latency: Duration? = nil,
        lastSeenAt: Date = Date()
    ) {
        self.id               = id
        self.name             = name
        self.productName      = productName
        self.address          = address
        self.port             = port
        self.mdnsHostname     = mdnsHostname
        self.ledCount         = ledCount
        self.firmwareVersion  = firmwareVersion
        self.activeProtocol   = activeProtocol
        self.connectionStatus = connectionStatus
        self.latency          = latency
        self.lastSeenAt       = lastSeenAt
    }

    /// Returns a copy with updated connection status and latency.
    public func with(
        connectionStatus: ConnectionStatus? = nil,
        latency: Duration? = nil,
        address: String? = nil
    ) -> DeviceInfo {
        DeviceInfo(
            id: id,
            name: name,
            productName: productName,
            address: address ?? self.address,
            port: port,
            mdnsHostname: mdnsHostname,
            ledCount: ledCount,
            firmwareVersion: firmwareVersion,
            activeProtocol: activeProtocol,
            connectionStatus: connectionStatus ?? self.connectionStatus,
            latency: latency ?? self.latency,
            lastSeenAt: Date()
        )
    }
}

// MARK: - ConnectionStatus

public enum ConnectionStatus: String, Codable, Sendable {
    case connected    = "Connected"
    case connecting   = "Connecting"
    case disconnected = "Disconnected"
    case error        = "Error"

    public var isActive: Bool { self == .connected }

    public var symbolName: String {
        switch self {
        case .connected:    return "checkmark.circle.fill"
        case .connecting:   return "arrow.clockwise.circle.fill"
        case .disconnected: return "xmark.circle.fill"
        case .error:        return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - ControllerProtocol

public enum ControllerProtocol: String, Codable, CaseIterable, Sendable {
    case udpRaw  = "UDP Raw"
    case ddp     = "DDP"
    case wledJSON = "WLED JSON"

    public var displayName: String { rawValue }
    public var defaultPort: UInt16 {
        switch self {
        case .udpRaw:   return 21324
        case .ddp:      return 4048
        case .wledJSON: return 80
        }
    }
}
