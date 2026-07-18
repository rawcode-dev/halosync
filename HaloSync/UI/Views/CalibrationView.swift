// HaloSync — UI/Views/CalibrationView.swift
// LED strip health verification and calibration.
// Runs color tests, brightness sweeps, and LED walk to identify dead/wrong LEDs.

import SwiftUI

// MARK: - CalibrationView

struct CalibrationView: View {
    @EnvironmentObject private var monitor: ControllerMonitor
    @EnvironmentObject private var settings: HaloSyncSettingsStore

    @State private var selectedTest: CalibrationTest? = nil
    @State private var isRunning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                pageHeader
                if monitor.discoveredDevice == nil {
                    noControllerBanner
                } else {
                    testGrid
                    brightnessTests
                    advancedSection
                }
            }
            .padding(Spacing.xl)
        }
        .navigationTitle("Calibration")
    }

    // MARK: - Sections

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Calibration")
                .font(Typography.title)
            Text("Test your LED strip for dead LEDs, color issues, and power problems")
                .font(Typography.body)
                .foregroundStyle(.secondary)
        }
    }

    private var noControllerBanner: some View {
        GlassCard {
            HStack(spacing: Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.haloWarning)
                VStack(alignment: .leading) {
                    Text("No Controller Connected")
                        .font(Typography.bodyMedium)
                    Text("Connect your Pixylights controller to run calibration tests")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var testGrid: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Color Tests".uppercased())
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .tracking(1.2)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 4), spacing: Spacing.sm) {
                ForEach(CalibrationTest.colorTests) { test in
                    CalibrationTestButton(test: test, isActive: selectedTest?.id == test.id, isRunning: isRunning) {
                        selectedTest = test
                        Task { await runTest(test) }
                    }
                }
            }
        }
    }

    private var brightnessTests: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Brightness Tests".uppercased())
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .tracking(1.2)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 5), spacing: Spacing.sm) {
                ForEach(CalibrationTest.brightnessTests) { test in
                    CalibrationTestButton(test: test, isActive: selectedTest?.id == test.id, isRunning: isRunning) {
                        selectedTest = test
                        Task { await runTest(test) }
                    }
                }
            }
        }
    }

    private var advancedSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Advanced".uppercased())
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                HStack(spacing: Spacing.md) {
                    CalibrationActionButton(title: "Walk LEDs", icon: "arrow.right.to.line", accent: .haloAccent) {
                        Task { await runWalk() }
                    }
                    CalibrationActionButton(title: "All Off", icon: "moon.fill", accent: Color(white: 0.5)) {
                        Task { await turnOff() }
                    }
                }
            }
        }
    }

    // MARK: - Logic

    private func runTest(_ test: CalibrationTest) async {
        isRunning = true
        HaloLogger.calibration.info("Running test: \(test.name)")
        // TODO: Phase 11 — connect to CalibrationEngine and send frames to controller
        try? await Task.sleep(for: .seconds(0.5))
        isRunning = false
    }

    private func runWalk() async {
        isRunning = true
        HaloLogger.calibration.info("Running LED walk")
        // TODO: Phase 11
        try? await Task.sleep(for: .seconds(1))
        isRunning = false
    }

    private func turnOff() async {
        HaloLogger.calibration.info("Turning off all LEDs")
        // TODO: Phase 11
    }
}

// MARK: - CalibrationTest Model

struct CalibrationTest: Identifiable {
    let id: String
    let name: String
    let color: Color
    let icon: String
    let ledColor: LEDColor

    static let colorTests: [CalibrationTest] = [
        CalibrationTest(id: "white",   name: "White",   color: .white,        icon: "circle.fill",     ledColor: .white),
        CalibrationTest(id: "red",     name: "Red",     color: .haloError,    icon: "circle.fill",     ledColor: .red),
        CalibrationTest(id: "green",   name: "Green",   color: .haloSuccess,  icon: "circle.fill",     ledColor: .green),
        CalibrationTest(id: "blue",    name: "Blue",    color: .haloPrimary,  icon: "circle.fill",     ledColor: .blue),
        CalibrationTest(id: "yellow",  name: "Yellow",  color: .haloWarning,  icon: "circle.fill",     ledColor: LEDColor(red: 1, green: 1, blue: 0)),
        CalibrationTest(id: "purple",  name: "Purple",  color: Color(hex: "#9B59B6"), icon: "circle.fill", ledColor: LEDColor(red: 0.6, green: 0, blue: 1)),
        CalibrationTest(id: "rainbow", name: "Rainbow", color: .haloPrimary,  icon: "rainbow",          ledColor: .white),
    ]

    static let brightnessTests: [CalibrationTest] = [
        CalibrationTest(id: "b0",   name: "0%",   color: Color(white: 0.15), icon: "sun.min",    ledColor: .black),
        CalibrationTest(id: "b25",  name: "25%",  color: Color(white: 0.30), icon: "sun.min",    ledColor: LEDColor(red: 0.25, green: 0.25, blue: 0.25)),
        CalibrationTest(id: "b50",  name: "50%",  color: Color(white: 0.50), icon: "sun.max",    ledColor: LEDColor(red: 0.5,  green: 0.5,  blue: 0.5)),
        CalibrationTest(id: "b75",  name: "75%",  color: Color(white: 0.75), icon: "sun.max",    ledColor: LEDColor(red: 0.75, green: 0.75, blue: 0.75)),
        CalibrationTest(id: "b100", name: "100%", color: .white,             icon: "sun.max.fill", ledColor: .white),
    ]
}

// MARK: - Supporting Components

struct CalibrationTestButton: View {
    let test: CalibrationTest
    let isActive: Bool
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Circle()
                    .fill(test.color)
                    .frame(width: 28, height: 28)
                    .overlay(Circle().strokeBorder(isActive ? Color.white : Color.clear, lineWidth: 2))
                Text(test.name)
                    .font(Typography.caption)
                    .foregroundStyle(isActive ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(isActive ? test.color.opacity(0.2) : Color.haloCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .strokeBorder(isActive ? test.color.opacity(0.6) : Color.haloBorder)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(Anim.snap, value: isActive)
    }
}

struct CalibrationActionButton: View {
    let title: String
    let icon: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(Typography.bodyMedium)
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(accent.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(accent.opacity(0.3)))
                )
        }
        .buttonStyle(.plain)
    }
}
