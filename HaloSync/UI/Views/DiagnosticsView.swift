// HaloSync — UI/Views/DiagnosticsView.swift
// Live system metrics dashboard and diagnostics report export.

import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var diagnostics: DiagnosticsService
    @State private var showExportSheet = false
    @State private var reportText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                pageHeader

                // Performance Section
                section(title: "Performance") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 3), spacing: Spacing.sm) {
                        MetricCard(title: "Capture FPS",  value: fmtNum(diagnostics.snapshot.captureFPS,      decimals: 1), unit: "fps", accent: .haloSuccess, icon: "camera")
                        MetricCard(title: "Capture Lat.", value: fmtNum(diagnostics.snapshot.captureLatencyMs, decimals: 2), unit: "ms",  accent: .haloPrimary, icon: "timer")
                        MetricCard(title: "GPU Time",     value: fmtNum(diagnostics.snapshot.gpuProcessingMs,  decimals: 2), unit: "ms",  accent: .haloAccent,  icon: "cpu")
                        MetricCard(title: "Network Lat.", value: fmtNum(diagnostics.snapshot.networkLatencyMs, decimals: 2), unit: "ms",  accent: .haloWarning, icon: "network")
                        MetricCard(title: "Total Lat.",   value: fmtNum(diagnostics.snapshot.totalLatencyMs,   decimals: 2), unit: "ms",  accent: .haloPrimary, icon: "arrow.left.arrow.right")
                        MetricCard(title: "Packet Loss",  value: fmtNum(diagnostics.snapshot.packetLoss * 100, decimals: 1), unit: "%",   accent: .haloError,   icon: "exclamationmark.triangle")
                    }
                }

                // Controller Section
                section(title: "Controller") {
                    infoRow("Name",      value: diagnostics.snapshot.controllerName)
                    infoRow("Address",   value: diagnostics.snapshot.controllerAddress)
                    infoRow("Firmware",  value: diagnostics.snapshot.firmwareVersion)
                    infoRow("LEDs",      value: "\(diagnostics.snapshot.ledCount)")
                    infoRow("Protocol",  value: diagnostics.snapshot.activeProtocol)
                }

                // System Section
                section(title: "System") {
                    infoRow("Monitor",     value: diagnostics.snapshot.currentMonitorName)
                    infoRow("App Version", value: diagnostics.snapshot.appVersion)
                    infoRow("Platform",    value: "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
                }

                // Export Button
                Button {
                    reportText = diagnostics.exportReport()
                    showExportSheet = true
                } label: {
                    Label("Export Diagnostics Report", systemImage: "square.and.arrow.up")
                        .font(Typography.bodyMedium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .fill(Color.haloPrimary.opacity(0.15))
                                .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(Color.haloPrimary.opacity(0.4)))
                        )
                        .foregroundStyle(.haloPrimary)
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.xl)
        }
        .navigationTitle("Diagnostics")
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(text: reportText)
        }
    }

    // MARK: - Helpers

    private var pageHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Diagnostics")
                    .font(Typography.title)
                Text("Live system metrics")
                    .font(Typography.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Live indicator
            HStack(spacing: Spacing.xs) {
                Circle().fill(Color.haloSuccess).frame(width: 6, height: 6)
                Text("LIVE")
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
            }
        }
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title.uppercased())
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .tracking(1.2)
            GlassCard {
                VStack(spacing: Spacing.md) {
                    content()
                }
            }
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Typography.body)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(Typography.monoMedium)
                .foregroundStyle(.primary)
        }
    }

    private func fmtNum(_ value: Double, decimals: Int) -> String {
        String(format: "%.\(decimals)f", value)
    }
}

// MARK: - ExportSheet

struct ExportSheet: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Spacing.xl) {
            HStack {
                Text("Diagnostics Report")
                    .font(Typography.headline)
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.plain).foregroundStyle(.haloPrimary)
            }
            ScrollView {
                Text(text)
                    .font(Typography.mono)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .background(Color.haloCard)
            .cornerRadius(Radius.sm)
        }
        .padding(Spacing.xl)
        .frame(width: 520, height: 480)
        .background(Color.haloBackground)
    }
}
