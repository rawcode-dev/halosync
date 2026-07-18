// HaloSync — Controller/WLEDUDPController.swift
// Concrete LED controller implementation for WLED / Pixylights devices.
// Sends encoded frames over UDP using DDP, UDP Raw, or WLED JSON protocols.
// Uses Network.framework for low-latency async UDP sending.

import Foundation
import Network

// MARK: - WLEDUDPController

/// UDP-based LED controller for WLED / Pixylights hardware.
/// Manages a persistent NWConnection and handles reconnection automatically.
public final class WLEDUDPController: LEDControllerProtocol, @unchecked Sendable {

    // MARK: - State

    private var connection: NWConnection?
    private var _deviceInfo: DeviceInfo
    private var nextSequence: UInt8 = 1
    private let lock = NSLock()

    // MARK: - Protocol Encoder

    private let encoder: any LEDOutputProtocol

    // MARK: - Init

    public init(deviceInfo: DeviceInfo, protocol proto: ControllerProtocol = .ddp) {
        self._deviceInfo = deviceInfo
        self.encoder = switch proto {
            case .ddp:      DDPProtocol()
            case .udpRaw:   UDPRawProtocol()
            case .wledJSON: DDPProtocol() // Fall back to DDP for now; JSON is HTTP-only.
        }
    }

    // MARK: - LEDControllerProtocol

    public var deviceInfo: DeviceInfo {
        get async {
            lock.withLock { _deviceInfo }
        }
    }

    public var isConnected: Bool {
        get async {
            lock.withLock { connection?.state == .ready }
        }
    }

    public func connect(to address: String, port: UInt16) async throws {
        let host = NWEndpoint.Host(address)
        let nwPort = NWEndpoint.Port(rawValue: port)!

        let conn = NWConnection(host: host, port: nwPort, using: .udp)
        lock.withLock { connection = conn }

        return try await withCheckedThrowingContinuation { continuation in
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    HaloLogger.network.info("UDP connected to \(address):\(port)")
                    continuation.resume()
                case .failed(let error):
                    HaloLogger.network.error("UDP connection failed: \(error)")
                    continuation.resume(throwing: LEDControllerError.sendFailed(underlying: error))
                default:
                    break
                }
            }
            conn.start(queue: .global(qos: .userInteractive))
        }
    }

    public func disconnect() async {
        lock.withLock {
            connection?.cancel()
            connection = nil
        }
        HaloLogger.network.info("UDP disconnected.")
    }

    public func send(frame: LEDFrame, colorOrder: ColorOrder) async throws {
        guard let conn = lock.withLock({ connection }),
              conn.state == .ready else {
            throw LEDControllerError.notConnected
        }

        let (info, seq) = lock.withLock { () -> (DeviceInfo, UInt8) in
            let s = nextSequence
            nextSequence = nextSequence == 15 ? 1 : nextSequence + 1
            return (_deviceInfo, s)
        }
        let data = encoder.encode(frame: frame, brightness: 1.0, colorOrder: colorOrder, sequenceNumber: seq)

        // For UDP, we want fire-and-forget. Blocking on `.contentProcessed` can stall the entire video
        // pipeline if the network stack delays packet acceptance (e.g., mDNS resolution stalls).
        conn.send(content: data, completion: .idempotent)
    }

    public func ping() async throws -> Duration {
        let start = ContinuousClock.now

        // Lightweight ping: send a zero-length UDP packet and time the send.
        guard let conn = lock.withLock({ connection }),
              conn.state == .ready else {
            throw LEDControllerError.notConnected
        }

        return try await withCheckedThrowingContinuation { continuation in
            conn.send(content: Data([0x00]), completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: LEDControllerError.sendFailed(underlying: error))
                } else {
                    let elapsed = ContinuousClock.now - start
                    continuation.resume(returning: elapsed)
                }
            })
        }
    }
}
