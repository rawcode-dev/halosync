// HaloSync — Controller/Protocols/UDPRawProtocol.swift
// Raw UDP protocol encoder.
// Simple 3-byte-per-LED format compatible with basic WLED / Adalight receivers.

import Foundation

/// Raw UDP protocol encoder.
/// Format: [R0, G0, B0, R1, G1, B1, ...] — one 3-byte triple per LED.
/// No header — very low overhead, maximum throughput.
public struct UDPRawProtocol: LEDOutputProtocol, Sendable {

    public var name: String { "UDP Raw" }
    public var defaultPort: UInt16 { 21324 }

    public func encode(frame: LEDFrame, brightness: Float, colorOrder: ColorOrder, sequenceNumber: UInt8) -> Data {
        var data = Data(capacity: frame.ledCount * 3)
        for led in frame.colors {
            let scaled = led.scaled(by: brightness)
            let (c0, c1, c2) = scaled.toBytes(order: colorOrder)
            data.append(contentsOf: [c0, c1, c2])
        }
        return data
    }
}
