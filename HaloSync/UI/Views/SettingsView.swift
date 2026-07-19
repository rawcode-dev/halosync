// HaloSync — UI/Views/SettingsView.swift
// Basic and Advanced settings. Advanced section is collapsed by default.

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: HaloSyncSettingsStore
    @State private var showAdvanced = false
    
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
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Settings")
                        .font(Typography.title)
                    Text("Customize HaloSync behavior")
                        .font(Typography.body)
                        .foregroundStyle(.secondary)
                }

                // Basic Settings
                settingsSection(title: "General") {
                    Toggle("Launch at Login", isOn: $settings.value.launchAtLogin)
                    Toggle("Start Minimized", isOn: $settings.value.startMinimized)
                    Toggle("Auto Reconnect", isOn: $settings.value.autoReconnect)
                }
                
                // Color Calibration
                settingsSection(title: "Color Calibration") {
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Wall Color Match")
                                .font(Typography.bodyMedium)
                            Text("Pick the physical color of the wall behind your monitor. HaloSync will automatically subtract this color to ensure accurate reflections.")
                                .font(Typography.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: Spacing.xl)
                        ColorPicker("", selection: wallColorBinding, supportsOpacity: false)
                            .labelsHidden()
                    }
                }

                // Advanced Settings (collapsed)
                DisclosureGroup(isExpanded: $showAdvanced) {
                    VStack(spacing: Spacing.md) {
                        // Sampling Depth
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Sampling Depth")
                                    .font(Typography.bodyMedium)
                                Text("Pixels from screen edge to sample")
                                    .font(Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Stepper("\(settings.value.samplingDepth) px", value: $settings.value.samplingDepth, in: 1...10)
                                .labelsHidden()
                            Text("\(settings.value.samplingDepth) px")
                                .font(Typography.monoMedium)
                                .foregroundStyle(.haloPrimary)
                                .frame(width: 40)
                        }

                        Divider().opacity(0.3)

                        // Color Order
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Color Order")
                                    .font(Typography.bodyMedium)
                                Text("LED strip byte order")
                                    .font(Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Picker("", selection: $settings.value.colorOrder) {
                                ForEach(ColorOrder.allCases, id: \.self) { order in
                                    Text(order.displayName).tag(order)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 100)
                        }

                        Divider().opacity(0.3)

                        // Protocol
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Protocol")
                                    .font(Typography.bodyMedium)
                                Text("Wire protocol for LED data")
                                    .font(Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Picker("", selection: $settings.value.activeProtocol) {
                                ForEach(ControllerProtocol.allCases, id: \.self) { p in
                                    Text(p.displayName).tag(p)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 130)
                        }

                        Divider().opacity(0.3)

                        // Gamma
                        HStack {
                            Text("Gamma")
                                .font(Typography.bodyMedium)
                            Spacer()
                            Slider(value: $settings.value.gamma, in: 1.0...3.0, step: 0.1)
                                .frame(width: 120)
                            Text(String(format: "%.1f", settings.value.gamma))
                                .font(Typography.monoMedium)
                                .foregroundStyle(.haloPrimary)
                                .frame(width: 30)
                        }

                        Divider().opacity(0.3)

                        // UDP Port
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("UDP Port")
                                    .font(Typography.bodyMedium)
                                Text("Override default port (DDP: 4048)")
                                    .font(Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            TextField("4048", value: $settings.value.udpPort, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                    }
                } label: {
                    Label("Advanced Settings", systemImage: "slider.vertical.3")
                        .font(Typography.headline)
                        .foregroundStyle(showAdvanced ? .haloPrimary : .primary)
                }
                .padding(Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .fill(Color.haloCard)
                        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.haloBorder))
                )
            }
            .padding(Spacing.xl)
        }
        .navigationTitle("Settings")
        .toggleStyle(HaloToggleStyle())
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title.uppercased())
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .tracking(1.2)
            GlassCard {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    content()
                }
            }
        }
    }
}

// MARK: - HaloToggleStyle

struct HaloToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .font(Typography.bodyMedium)
            Spacer()
            Toggle("", isOn: configuration.$isOn)
                .toggleStyle(.switch)
                .tint(.haloPrimary)
        }
    }
}
