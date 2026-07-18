// HaloSync — Diagnostics/DiagnosticsService.swift
// Collects real-time performance metrics across all pipeline stages.
// Published via @Observable for the DiagnosticsView.
// All values are rolling averages to avoid jitter in the UI.

import Foundation
import OSLog

// MARK: - DiagnosticsSnapshot

/// A point-in-time snapshot of all system metrics.
public struct DiagnosticsSnapshot: Sendable {
    public var captureFPS:         Double = 0
    public var captureLatencyMs:   Double = 0
    public var gpuProcessingMs:    Double = 0
    public var networkLatencyMs:   Double = 0
    public var totalLatencyMs:     Double = 0
    public var packetLoss:         Double = 0    // 0.0 – 1.0
    public var currentMonitorName: String = "—"
    public var controllerName:     String = "—"
    public var controllerAddress:  String = "—"
    public var firmwareVersion:    String = "—"
    public var ledCount:           Int    = 0
    public var activeProtocol:     String = "—"
    public var appVersion:         String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
}

// MARK: - DiagnosticsService

/// Aggregates and publishes real-time performance metrics.
@MainActor
public final class DiagnosticsService: ObservableObject {

    // MARK: - Published

    @Published public private(set) var snapshot = DiagnosticsSnapshot()

    // MARK: - Rolling Accumulators (private)

    private var fpsHistory:        [Double] = []
    private var captureLatHistory: [Double] = []
    private var gpuLatHistory:     [Double] = []
    private var netLatHistory:     [Double] = []
    private var packetsSent:       Int = 0
    private var packetsLost:       Int = 0

    private let windowSize = 60  // 1-second window at 60fps

    // MARK: - Public Record Methods (called from pipeline stages)

    public func recordFrame(fps: Double, captureLatencyMs: Double) {
        append(fps, to: &fpsHistory)
        append(captureLatencyMs, to: &captureLatHistory)
        updateSnapshot()
    }

    public func recordGPU(processingMs: Double) {
        append(processingMs, to: &gpuLatHistory)
        updateSnapshot()
    }

    public func recordNetwork(latencyMs: Double, lost: Bool) {
        append(latencyMs, to: &netLatHistory)
        packetsSent += 1
        if lost { packetsLost += 1 }
        updateSnapshot()
    }

    /// Convenience: records all pipeline stage metrics in one call.
    public func record(fps: Double, captureLatencyMs: Double, gpuMs: Double, networkMs: Double) {
        append(fps,              to: &fpsHistory)
        append(captureLatencyMs, to: &captureLatHistory)
        append(gpuMs,            to: &gpuLatHistory)
        append(networkMs,        to: &netLatHistory)
        packetsSent += 1
        updateSnapshot()
    }

    public func updateDevice(info: DeviceInfo) {
        snapshot.controllerName    = info.name
        snapshot.controllerAddress = info.address
        snapshot.firmwareVersion   = info.firmwareVersion
        snapshot.ledCount          = info.ledCount
        snapshot.activeProtocol    = info.activeProtocol.rawValue
    }

    public func updateMonitor(name: String) {
        snapshot.currentMonitorName = name
    }

    // MARK: - Export

    public func exportReport() -> String {
        let s = snapshot
        return """
        HaloSync Diagnostics Report
        ============================
        Date: \(Date())
        App Version: \(s.appVersion)

        Performance
        -----------
        Capture FPS:         \(String(format: "%.1f", s.captureFPS)) fps
        Capture Latency:     \(String(format: "%.2f", s.captureLatencyMs)) ms
        GPU Processing:      \(String(format: "%.2f", s.gpuProcessingMs)) ms
        Network Latency:     \(String(format: "%.2f", s.networkLatencyMs)) ms
        Total Latency:       \(String(format: "%.2f", s.totalLatencyMs)) ms
        Packet Loss:         \(String(format: "%.1f", s.packetLoss * 100))%

        Controller
        ----------
        Name:      \(s.controllerName)
        Address:   \(s.controllerAddress)
        Firmware:  \(s.firmwareVersion)
        LED Count: \(s.ledCount)
        Protocol:  \(s.activeProtocol)

        Display
        -------
        Monitor: \(s.currentMonitorName)
        """
    }

    // MARK: - Private

    private func append(_ value: Double, to history: inout [Double]) {
        history.append(value)
        if history.count > windowSize { history.removeFirst() }
    }

    private func updateSnapshot() {
        snapshot.captureFPS       = average(fpsHistory)
        snapshot.captureLatencyMs = average(captureLatHistory)
        snapshot.gpuProcessingMs  = average(gpuLatHistory)
        snapshot.networkLatencyMs = average(netLatHistory)
        snapshot.totalLatencyMs   = snapshot.captureLatencyMs
                                  + snapshot.gpuProcessingMs
                                  + snapshot.networkLatencyMs
        snapshot.packetLoss = packetsSent > 0
            ? Double(packetsLost) / Double(packetsSent)
            : 0
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}
