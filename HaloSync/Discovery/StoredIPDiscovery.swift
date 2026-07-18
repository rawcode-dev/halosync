// HaloSync — Discovery/StoredIPDiscovery.swift
// Fallback discovery using a stored IP address from UserDefaults.
// Fires immediately on startup — no network scan needed.

import Foundation

/// Discovery method that uses a previously stored IP address.
/// This is tier-1 in the discovery chain — fastest possible reconnect.
public final class StoredIPDiscovery: DiscoveryServiceProtocol, @unchecked Sendable {

    public let name = "Stored IP"

    private let address: String
    private var continuation: AsyncStream<DiscoveryEvent>.Continuation?

    public init(address: String) {
        self.address = address
    }

    public func discover() -> AsyncStream<DiscoveryEvent> {
        let (stream, continuation) = AsyncStream<DiscoveryEvent>.makeStream()
        self.continuation = continuation

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.probe()
        }

        return stream
    }

    public func stop() async {
        continuation?.finish()
        continuation = nil
    }

    // MARK: - Private

    private func probe() async {
        HaloLogger.discovery.info("StoredIP: probing \(self.address)...")

        guard let request = WLEDJSONProtocol.infoRequest(host: self.address) else { return }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }

            if let info = WLEDJSONProtocol.parseInfoResponse(data, address: self.address) {
                continuation?.yield(.found(info))
                HaloLogger.discovery.info("StoredIP: found \(info.name) at \(self.address)")
            }
        } catch {
            HaloLogger.discovery.warning("StoredIP probe failed: \(error)")
        }

        // Signal completion — this discovery method is one-shot.
        continuation?.finish()
    }
}
