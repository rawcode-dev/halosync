// HaloSync — Controller/Protocols/DDPProtocol.swift
// Distributed Display Protocol (DDP) encoder.
// DDP is the default protocol for Pixylights SyncOne.
// Spec: https://www.3waylabs.com/ddp/

import Foundation

/// DDP packet encoder.
/// DDP is efficient, low-overhead, and widely supported by WLED / Pixylights.
public struct DDPProtocol: LEDOutputProtocol, Sendable {

    // MARK: - Constants

    private enum DDP {
        static let header: [UInt8] = [
            0x41,   // Flags: VER=1, TIMECODE=0, STORAGE=0, REPLY=0, QUERY=0, PUSH=1
            0x00,   // Sequence number (managed per-connection, set to 0 for stateless)
            0x01,   // Data type: 0x01 = RGB
            0x01,   // Device ID: 1 = default
        ]
        static let port: UInt16 = 4048
    }

    // MARK: - LEDOutputProtocol

    public var name: String { "DDP" }
    public var defaultPort: UInt16 { DDP.port }

    public func encode(frame: LEDFrame, brightness: Float, colorOrder: ColorOrder, sequenceNumber: UInt8 = 0) -> Data {
        let leds    = frame.colors
        let dataLen = leds.count * 3

        var packet = Data(capacity: 10 + dataLen)

        // Header (10 bytes)
        packet.append(contentsOf: [
            0x41,           // Flags: VER=1, PUSH=1
            sequenceNumber, // Sequence number (1-15, 0 = ignore)
            0x01,           // Data type: RGB
            0x01,           // Device ID: 1
            0x00, 0x00, 0x00, 0x00 // Offset: 0
        ])

        // Data length: 2-byte big-endian
        let lenHi = UInt8((dataLen >> 8) & 0xFF)
        let lenLo = UInt8(dataLen & 0xFF)
        packet.append(contentsOf: [lenHi, lenLo])

        // LED data
        for led in leds {
            let scaled = led.scaled(by: brightness)
            let (c0, c1, c2) = scaled.toBytes(order: colorOrder)
            packet.append(contentsOf: [c0, c1, c2])
        }

        return packet
    }
}
