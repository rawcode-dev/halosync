// HaloSync — Controller/Protocols/WLEDJSONProtocol.swift
// WLED JSON API protocol encoder.
// Used for initial device discovery and LED count validation.
// Not used in the hot path — DDP is used for real-time data.

import Foundation

/// WLED JSON API encoder.
/// Used for: controller discovery, LED count query, state set, ping.
/// NOT used for real-time frame data (too slow) — DDP handles that.
public struct WLEDJSONProtocol: LEDOutputProtocol, Sendable {

    public var name: String { "WLED JSON" }
    public var defaultPort: UInt16 { 80 }

    // MARK: - Frame Encoding

    /// Encodes an LED frame as WLED JSON (used only for testing/calibration).
    public func encode(frame: LEDFrame, brightness: Float, colorOrder: ColorOrder, sequenceNumber: UInt8) -> Data {
        var segments: [[String: Any]] = []
        var colors: [[Int]] = []

        for led in frame.colors {
            let scaled = led.scaled(by: brightness)
            let (r, g, b) = scaled.toBytes(order: colorOrder)
            colors.append([Int(r), Int(g), Int(b)])
        }

        let segment: [String: Any] = ["i": flattenColors(colors)]
        segments.append(segment)

        let payload: [String: Any] = ["seg": segments]
        return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
    }

    private func flattenColors(_ colors: [[Int]]) -> [Int] {
        colors.flatMap { $0 }
    }

    // MARK: - API Helpers

    /// Builds a GET request to the WLED JSON info endpoint.
    public static func infoRequest(host: String) -> URLRequest? {
        guard let url = URL(string: "http://\(host)/json/info") else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 3)
        req.httpMethod = "GET"
        return req
    }

    /// Builds a POST request to toggle the WLED device power state.
    public static func powerRequest(host: String, isOn: Bool) -> URLRequest? {
        guard let url = URL(string: "http://\(host)/json/state") else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 3)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = ["on": isOn]
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        return req
    }
    
    /// Builds a POST request to set the WLED device to a permanent solid color effect.
    public static func solidColorRequest(host: String, color: SIMD3<Float>) -> URLRequest? {
        guard let url = URL(string: "http://\(host)/json/state") else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 3)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let r = Int((color.x * 255).rounded())
        let g = Int((color.y * 255).rounded())
        let b = Int((color.z * 255).rounded())
        
        // fx: 0 is the Solid color effect in WLED.
        let payload: [String: Any] = [
            "on": true,
            "seg": [
                [
                    "fx": 0,
                    "col": [[r, g, b]]
                ]
            ]
        ]
        
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        return req
    }

    /// Parses a WLED /json/info response into a partial DeviceInfo.
    public static func parseInfoResponse(_ data: Data, address: String) -> DeviceInfo? {
        guard
            let json     = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let ledInfo  = json["leds"] as? [String: Any],
            let count    = ledInfo["count"] as? Int,
            let ver      = json["ver"] as? String,
            let name     = json["name"] as? String
        else {
            return nil
        }

        return DeviceInfo(
            name:            name,
            address:         address,
            ledCount:        count,
            firmwareVersion: ver,
            activeProtocol:  .ddp,
            connectionStatus: .disconnected
        )
    }
}
