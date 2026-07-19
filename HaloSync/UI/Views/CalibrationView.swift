// HaloSync — UI/Views/CalibrationView.swift
// LED strip health verification and calibration.
// Runs color tests, brightness sweeps, and LED walk to identify dead/wrong LEDs.

import SwiftUI

// MARK: - CalibrationView

struct CalibrationView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var monitor: ControllerMonitor
    @EnvironmentObject private var settings: HaloSyncSettingsStore

    @State private var selectedTest: CalibrationTest? = nil
    @State private var isRunning = false
    @State private var testTask: Task<Void, Never>? = nil
    
    private var wallColorBinding: Binding<Color> {
        Binding(
            get: {
                let w = settings.value.wallColor
                return Color(red: Double(w.x), green: Double(w.y), blue: Double(w.z))
            },
            set: { newColor in
                if let nsColor = NSColor(newColor).usingColorSpace(.deviceRGB) {
                    settings.value.wallColor = SIMD3<Float>(
                        Float(nsColor.redComponent),
                        Float(nsColor.greenComponent),
                        Float(nsColor.blueComponent)
                    )
                }
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                pageHeader
                if monitor.discoveredDevice == nil {
                    noControllerBanner
                } else {
                    wallColorMatchSection
                    testGrid
                    brightnessTests
                    advancedSection
                }
            }
            .padding(Spacing.xl)
        }
        .navigationTitle("Calibration")
        .onAppear {
            if env.pipeline.isRunning {
                Task { await env.stopPipeline() }
            }
        }
        .onDisappear {
            testTask?.cancel()
        }
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
    
    private var wallColorMatchSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Wall Color Match".uppercased())
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .tracking(1.2)
            
            GlassCard {
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Physical Wall Color")
                            .font(Typography.bodyMedium)
                        Text("Pick the color of the wall behind your monitor. The system will subtract this color from the LEDs so reflections appear accurate.")
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: Spacing.xl)
                    ColorPicker("", selection: wallColorBinding, supportsOpacity: false)
                        .labelsHidden()
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
                        runTest(test)
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
                        runTest(test)
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

    private func runTest(_ test: CalibrationTest) {
        testTask?.cancel()
        testTask = Task {
            isRunning = true
            HaloLogger.calibration.info("Running test: \(test.name)")
            
            guard let device = monitor.discoveredDevice else {
                isRunning = false
                return
            }
            
            let controller = WLEDUDPController(deviceInfo: device)
            do {
                let port: UInt16 = device.activeProtocol == .udpRaw ? 21324 : 4048
                try await controller.connect(to: device.address, port: port)
                
                while !Task.isCancelled {
                    // Subtractive Wall Color Math
                    let pSettings = ProcessingSettings.from(mode: .custom, brightness: 1.0, ambientStrength: 1.0, wallColor: settings.value.wallColor)
                    let comp = pSettings.wallCompensation
                    let compensatedColor = LEDColor(
                        red: test.ledColor.red * comp.x,
                        green: test.ledColor.green * comp.y,
                        blue: test.ledColor.blue * comp.z
                    )
                    
                    let colors = Array(repeating: compensatedColor, count: device.ledCount)
                    let frame = LEDFrame(colors: colors, timestamp: .now, source: .calibration)
                    try await controller.send(frame: frame, colorOrder: settings.value.colorOrder)
                    
                    // WLED timeout is usually 2.5s, sending every 1 second keeps it alive.
                    try await Task.sleep(for: .seconds(1))
                }
                
                await controller.disconnect()
            } catch {
                if !Task.isCancelled {
                    HaloLogger.calibration.error("Failed to run test: \(error)")
                }
            }
            
            if !Task.isCancelled {
                isRunning = false
            }
        }
    }

    private func runWalk() async {
        testTask?.cancel()
        isRunning = true
        HaloLogger.calibration.info("Running LED walk")
        
        guard let device = monitor.discoveredDevice else {
            isRunning = false
            return
        }
        
        let controller = WLEDUDPController(deviceInfo: device)
        do {
            let port: UInt16 = device.activeProtocol == .udpRaw ? 21324 : 4048
            try await controller.connect(to: device.address, port: port)
            
            for i in 0..<device.ledCount {
                var colors = Array(repeating: LEDColor.black, count: device.ledCount)
                colors[i] = .white
                let frame = LEDFrame(colors: colors, timestamp: .now, source: .calibration)
                try await controller.send(frame: frame, colorOrder: settings.value.colorOrder)
                try await Task.sleep(for: .milliseconds(50)) // Wait slightly for visually pleasing walk
            }
            
            // Turn off at end
            let offColors = Array(repeating: LEDColor.black, count: device.ledCount)
            try await controller.send(frame: LEDFrame(colors: offColors, timestamp: .now, source: .calibration), colorOrder: settings.value.colorOrder)
            try await Task.sleep(for: .milliseconds(50))
            
            await controller.disconnect()
        } catch {
            HaloLogger.calibration.error("Walk failed: \(error)")
        }
        
        isRunning = false
    }

    private func turnOff() async {
        testTask?.cancel()
        selectedTest = nil
        HaloLogger.calibration.info("Turning off all LEDs")
        
        guard let device = monitor.discoveredDevice else { return }
        
        let controller = WLEDUDPController(deviceInfo: device)
        do {
            let port: UInt16 = device.activeProtocol == .udpRaw ? 21324 : 4048
            try await controller.connect(to: device.address, port: port)
            let colors = Array(repeating: LEDColor.black, count: device.ledCount)
            let frame = LEDFrame(colors: colors, timestamp: .now, source: .calibration)
            try await controller.send(frame: frame, colorOrder: settings.value.colorOrder)
            try await Task.sleep(for: .milliseconds(100))
            await controller.disconnect()
        } catch {
            HaloLogger.calibration.error("Turn off failed: \(error)")
        }
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
