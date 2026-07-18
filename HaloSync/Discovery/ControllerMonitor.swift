// HaloSync — Discovery/ControllerMonitor.swift
// Orchestrates the full discovery chain and continuously monitors connection health.
// This is the "smart reconnect" system described in the spec.
//
// Discovery chain:
//   1. Stored IP (instant, if available)
//   2. mDNS scan (finds new or moved controllers)
//   3. Manual IP entry (last resort, UI-triggered)
//
// After connection: heartbeat every 5s. If lost → re-run discovery chain.

import Foundation

// MARK: - ControllerMonitor

/// Manages the full lifecycle of controller discovery and reconnection.
/// Publishes DeviceInfo updates to subscribers via AsyncStream.
@MainActor
public final class ControllerMonitor: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var discoveredDevice: DeviceInfo?
    @Published public private(set) var isSearching: Bool = false

    // MARK: - Dependencies

    private let mdnsDiscovery: MDNSDiscovery
    private let sessionConfig: URLSessionConfiguration

    // MARK: - Private State

    private var heartbeatTask: Task<Void, Never>?
    private var discoveryTask: Task<Void, Never>?

    // MARK: - Init

    public init() {
        self.mdnsDiscovery = MDNSDiscovery()
        self.sessionConfig = URLSessionConfiguration.ephemeral
        self.sessionConfig.timeoutIntervalForRequest = 3
    }

    // MARK: - Public API

    /// Begins the discovery chain.
    /// - Parameter storedAddress: Previously known controller IP, if any.
    public func startDiscovery(storedAddress: String?) {
        discoveryTask?.cancel()
        discoveryTask = Task { [weak self] in
            guard let self else { return }
            await self.runDiscoveryChain(storedAddress: storedAddress)
        }
    }

    /// Forces an immediate reconnect attempt.
    public func reconnect() {
        let address = discoveredDevice?.address
        startDiscovery(storedAddress: address)
    }

    /// Manually sets a controller by IP (called from settings/onboarding).
    public func connect(toAddress address: String) async {
        let discovery = StoredIPDiscovery(address: address)
        for await event in discovery.discover() {
            await handle(event: event)
        }
    }

    /// Stops all monitoring.
    public func stop() {
        discoveryTask?.cancel()
        heartbeatTask?.cancel()
        isSearching = false
    }

    // MARK: - Private

    private func runDiscoveryChain(storedAddress: String?) async {
        isSearching = true
        HaloLogger.discovery.info("Starting discovery chain. Stored IP: \(storedAddress ?? "none")")

        // Tier 1: Stored IP
        if let stored = storedAddress {
            let storedDiscovery = StoredIPDiscovery(address: stored)
            for await event in storedDiscovery.discover() {
                await handle(event: event)
                if discoveredDevice != nil {
                    isSearching = false
                    startHeartbeat()
                    return
                }
            }
        }

        // Tier 2: mDNS
        HaloLogger.discovery.info("Stored IP failed, starting mDNS scan...")
        let mdnsStream = mdnsDiscovery.discover()
        let timeout = Task {
            try? await Task.sleep(for: .seconds(15))
        }

        for await event in mdnsStream {
            await handle(event: event)
            if discoveredDevice != nil {
                await mdnsDiscovery.stop()
                timeout.cancel()
                isSearching = false
                startHeartbeat()
                return
            }
            if timeout.isCancelled { break }
        }

        // Tier 3: No controller found — leave UI in "searching" state.
        isSearching = false
        HaloLogger.discovery.warning("Discovery chain completed — no controller found.")
    }

    private func handle(event: DiscoveryEvent) async {
        switch event {
        case .found(let info):
            discoveredDevice = info.with(connectionStatus: .connected)
            HaloLogger.discovery.info("Device found: \(info.name) @ \(info.address)")
        case .updated(let info):
            discoveredDevice = info
        case .lost:
            discoveredDevice = discoveredDevice?.with(connectionStatus: .disconnected)
            HaloLogger.discovery.info("Device lost — will attempt reconnect.")
            await runDiscoveryChain(storedAddress: discoveredDevice?.address)
        }
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                await self?.checkHeartbeat()
            }
        }
    }

    private func checkHeartbeat() async {
        guard let device = discoveredDevice else { return }
        guard let request = WLEDJSONProtocol.infoRequest(host: device.address) else { return }

        do {
            let session = URLSession(configuration: sessionConfig)
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                // Alive — update lastSeenAt silently.
                discoveredDevice = device.with(connectionStatus: .connected)
            }
        } catch {
            HaloLogger.discovery.warning("Heartbeat failed: \(error). Reconnecting...")
            discoveredDevice = device.with(connectionStatus: .disconnected)
            startDiscovery(storedAddress: device.address)
        }
    }
}
