// HaloSync — Discovery/MDNSDiscovery.swift
// Discovers WLED controllers on the local network via Bonjour/mDNS.
// Listens for _wled._tcp.local services.
// When found, probes the WLED JSON API to get LED count and firmware info.

import Foundation
import Network

// MARK: - MDNSDiscovery

/// Discovers WLED-compatible controllers via mDNS / Bonjour.
/// WLED controllers advertise themselves as _wled._tcp.local by default.
public final class MDNSDiscovery: DiscoveryServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    public let name = "mDNS / Bonjour"

    private let browser: NWBrowser
    private var continuation: AsyncStream<DiscoveryEvent>.Continuation?

    // MARK: - Init

    public init() {
        let params = NWParameters()
        params.includePeerToPeer = false
        self.browser = NWBrowser(for: .bonjourWithTXTRecord(type: "_wled._tcp", domain: "local."), using: params)
    }

    // MARK: - DiscoveryServiceProtocol

    public func discover() -> AsyncStream<DiscoveryEvent> {
        let (stream, continuation) = AsyncStream<DiscoveryEvent>.makeStream()
        self.continuation = continuation

        browser.browseResultsChangedHandler = { [weak self] results, changes in
            guard let self else { return }
            for change in changes {
                switch change {
                case .added(let result):
                    Task { await self.probe(result: result) }
                case .removed(let result):
                    if case .service(let name, _, _, _) = result.endpoint {
                        HaloLogger.discovery.info("mDNS: lost \(name)")
                        // Emit lost event using the name as a fallback identifier.
                        // (Full UUID requires a prior connection — we use name hash.)
                        self.continuation?.yield(.lost(deviceID: UUID(uuidString: name) ?? UUID()))
                    }
                default: break
                }
            }
        }

        browser.stateUpdateHandler = { state in
            switch state {
            case .failed(let err):
                HaloLogger.discovery.error("mDNS browser failed: \(err)")
            case .ready:
                HaloLogger.discovery.info("mDNS browser ready")
            default: break
            }
        }

        browser.start(queue: .global(qos: .utility))
        HaloLogger.discovery.info("mDNS discovery started")

        return stream
    }

    public func stop() async {
        browser.cancel()
        continuation?.finish()
        continuation = nil
        HaloLogger.discovery.info("mDNS discovery stopped")
    }

    // MARK: - Private

    private func probe(result: NWBrowser.Result) async {
        guard case .service(let serviceName, _, _, _) = result.endpoint else { return }

        HaloLogger.discovery.info("mDNS: found \(serviceName), probing WLED API...")

        // Resolve the service to an IP by connecting via NWConnection.
        // WLED runs its JSON API on port 80.
        let connection = NWConnection(to: result.endpoint, using: .tcp)
        let host: String

        // Use the service name as the hostname (Bonjour handles resolution).
        // WLED services are named like "WLED-AB12CD" and resolve via .local
        host = "\(serviceName).local"

        guard let request = WLEDJSONProtocol.infoRequest(host: host) else { return }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                connection.cancel()
                return
            }

            if let info = WLEDJSONProtocol.parseInfoResponse(data, address: host) {
                let found = info.with(connectionStatus: .disconnected)
                continuation?.yield(.found(found))
                HaloLogger.discovery.info("mDNS: discovered \(info.name) at \(host) with \(info.ledCount) LEDs")
            }
        } catch {
            HaloLogger.discovery.warning("mDNS probe failed for \(serviceName): \(error)")
        }
        connection.cancel()
    }
}
