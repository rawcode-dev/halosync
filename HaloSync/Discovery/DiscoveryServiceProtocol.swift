// HaloSync — Discovery/DiscoveryServiceProtocol.swift
// Protocol for any controller discovery mechanism.
// Implementations: MDNSDiscovery, StoredIPDiscovery.
// Orchestrated by ControllerMonitor.

import Foundation

// MARK: - DiscoveryEvent

/// Events emitted by a discovery service.
public enum DiscoveryEvent: Sendable {
    case found(DeviceInfo)
    case lost(deviceID: UUID)
    case updated(DeviceInfo)
}

// MARK: - DiscoveryServiceProtocol

/// A discovery mechanism that locates LED controllers on the local network.
public protocol DiscoveryServiceProtocol: AnyObject, Sendable {
    /// A human-readable name for this discovery method.
    var name: String { get }

    /// Begins discovery, streaming events until cancelled.
    func discover() -> AsyncStream<DiscoveryEvent>

    /// Stops all discovery activity.
    func stop() async
}
