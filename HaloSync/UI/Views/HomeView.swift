// HaloSync — UI/Views/HomeView.swift
// The primary screen. Controls, status, and mode selection in one glance.
// Everything the user needs 95% of the time is visible here.

import SwiftUI

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var settings: HaloSyncSettingsStore
    @EnvironmentObject private var monitor: ControllerMonitor
    @EnvironmentObject private var pipeline: AmbientPipeline

    @State private var glowPulse = false
    @State private var showDisplayPicker = false

    private var isRunning: Bool { pipeline.isRunning }
    
    private var solidColorBinding: Binding<Color> {
        Binding(
            get: {
                let c = settings.value.solidColor
                return Color(red: Double(c.x), green: Double(c.y), blue: Double(c.z))
            },
            set: { newColor in
                if let nsColor = NSColor(newColor).usingColorSpace(.deviceRGB) {
                    settings.value.solidColor = SIMD3<Float>(
                        Float(nsColor.redComponent),
                        Float(nsColor.greenComponent),
                        Float(nsColor.blueComponent)
                    )
                    if settings.value.activeMode == .solid {
                        Task { await env.applySolidColorToHardware() }
                    }
                }
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                headerSection
                
                VStack(spacing: Spacing.xl) {
                    statusRow
                    controlsSection
                }
                .disabled(!env.isDeviceOn)
                .opacity(env.isDeviceOn ? 1.0 : 0.5)
                .animation(Anim.snap, value: env.isDeviceOn)
            }
            .padding(Spacing.xl)
        }
        .background(backgroundGradient)
        .navigationTitle("Home")
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("HaloSync")
                    .font(Typography.display)
                    .foregroundStyle(.primary)
                Text(env.isDeviceOn ? (isRunning ? "Syncing screen" : "Lighting is active") : (monitor.discoveredDevice == nil ? "No controller found" : "Lighting is off"))
                    .font(Typography.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Primary power button (Hardware power)
            Button {
                Task {
                    let newState = !env.isDeviceOn
                    await env.toggleDevicePower(isOn: newState)
                    withAnimation(Anim.snap) { glowPulse = newState }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(env.isDeviceOn
                              ? LinearGradient(colors: [.haloPrimary, .haloAccent], startPoint: .topLeading, endPoint: .bottomTrailing)
                              : LinearGradient(colors: [Color.haloCard, Color.haloCard], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: env.isDeviceOn ? Color.haloPrimary.opacity(glowPulse ? 0.7 : 0.3) : .clear, radius: 20)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: glowPulse)

                    Image(systemName: "power")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(env.isDeviceOn ? .white : .secondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(monitor.discoveredDevice == nil)
        }
    }

    private var statusRow: some View {
        HStack(spacing: Spacing.md) {
            // Controller card
            GlassCard(padding: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 16))
                        .foregroundStyle(.haloPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(monitor.discoveredDevice?.name ?? "No Controller")
                            .font(Typography.bodyMedium)
                            .lineLimit(1)
                        StatusBadge(status: env.isDeviceOn ? (monitor.discoveredDevice?.connectionStatus ?? .disconnected) : .disconnected)
                    }
                    Spacer()
                    if let latency = monitor.discoveredDevice?.latency {
                        let ms = latency.components.seconds * 1000 + latency.components.attoseconds / 1_000_000_000_000_000
                        Text("\(ms)ms")
                            .font(Typography.mono)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Monitor card
            Menu {
                ForEach(env.currentDisplays, id: \.uuid) { display in
                    Button {
                        Task {
                            await env.selectDisplay(uuid: display.uuid)
                        }
                    } label: {
                        HStack {
                            Text(display.name)
                            if settings.value.selectedDisplayUUID == display.uuid || (settings.value.selectedDisplayUUID == nil && display.isMain) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                GlassCard(padding: Spacing.md) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "display")
                            .font(.system(size: 16))
                            .foregroundStyle(.haloAccent)
                        
                        // Compute active display info
                        let activeDisplay = env.currentDisplays.first(where: { $0.uuid == settings.value.selectedDisplayUUID })
                                         ?? env.currentDisplays.first(where: { $0.isMain })
                                         ?? env.currentDisplays.first

                        VStack(alignment: .leading, spacing: 2) {
                            Text(activeDisplay?.name ?? "No Display")
                                .font(Typography.bodyMedium)
                                .lineLimit(1)
                            if let display = activeDisplay {
                                Text("\(Int(display.resolution.width))×\(Int(display.resolution.height)) · \(Int(display.refreshRate)) Hz")
                                    .font(Typography.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Waiting for display...")
                                    .font(Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(env.currentDisplays.count <= 1)
        }
    }

    private var controlsSection: some View {
        GlassCard {
            VStack(spacing: Spacing.xl) {
                
                // Screen Sync Toggle
                HStack {
                    Image(systemName: "rectangle.inset.filled.and.person.filled")
                        .foregroundStyle(.haloPrimary)
                        .font(.system(size: 18))
                    VStack(alignment: .leading) {
                        Text("Screen Sync")
                            .font(Typography.bodyMedium)
                        Text("Match LEDs to display content")
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { isRunning && settings.value.activeMode != .effects },
                        set: { enable in
                            Task {
                                if enable {
                                    settings.value.activeMode = .ambient
                                    // Ensure hardware is on before syncing
                                    if !env.isDeviceOn {
                                        await env.toggleDevicePower(isOn: true)
                                    }
                                    if !pipeline.isRunning {
                                        await env.startPipeline()
                                    }
                                } else {
                                    await env.stopPipeline()
                                }
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .tint(.haloPrimary)
                }
                
                Divider().opacity(0.5)
                
                // Presets Grid
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Sync Presets")
                        .font(Typography.headline)
                        .foregroundStyle(.primary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 4), spacing: Spacing.sm) {
                        ForEach(AmbientMode.allCases) { mode in
                            ModeTile(
                                mode: mode,
                                isSelected: settings.value.activeMode == mode
                            ) {
                                withAnimation(Anim.snap) {
                                    settings.value.activeMode = mode
                                    if mode != .custom {
                                        let defaults = mode.defaultParameters
                                        settings.value.brightness = defaults.brightness
                                        settings.value.smoothness = defaults.smoothness
                                        settings.value.ambientStrength = defaults.ambientStrength
                                    }
                                }
                                if mode == .solid {
                                    Task {
                                        await env.stopPipeline()
                                        await env.applySolidColorToHardware()
                                    }
                                } else if !pipeline.isRunning {
                                    Task { await env.startPipeline() }
                                }
                            }
                        }
                    }
                    
                    if settings.value.activeMode == .solid {
                        solidColorSection
                    }
                }

                Divider().opacity(0.5)

                HaloSlider(
                    title: "Brightness",
                    value: $settings.value.brightness,
                    accentColors: [.haloPrimary, .haloAccent],
                    icon: "sun.max.fill"
                )
                .disabled(settings.value.activeMode != .custom)
                .opacity(settings.value.activeMode != .custom ? 0.5 : 1.0)
                
                HaloSlider(
                    title: "Smoothness",
                    value: $settings.value.smoothness,
                    accentColors: [.haloAccent, .haloPrimary],
                    icon: "drop.fill"
                )
                .disabled(settings.value.activeMode != .custom)
                .opacity(settings.value.activeMode != .custom ? 0.5 : 1.0)
                
                HaloSlider(
                    title: "Ambient Strength",
                    value: $settings.value.ambientStrength,
                    accentColors: [.haloPrimary, .haloSuccess],
                    icon: "sparkles"
                )
                .disabled(settings.value.activeMode != .custom)
                .opacity(settings.value.activeMode != .custom ? 0.5 : 1.0)
            }
        }
    }
    
    private var solidColorSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Hardware Color")
                    .font(Typography.bodyMedium)
                Text("Select the permanent fallback color for your LEDs.")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ColorPicker("", selection: solidColorBinding, supportsOpacity: false)
                .labelsHidden()
        }
        .padding()
        .background(Color.haloCard)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    private var metricsRow: some View {
        MetricsRow()
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.haloBackground,
                Color.haloPrimary.opacity(0.04),
                Color.haloBackground
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - MetricsRow

struct MetricsRow: View {
    @EnvironmentObject private var diagnostics: DiagnosticsService

    var body: some View {
        let snap = diagnostics.snapshot
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 3), spacing: Spacing.sm) {
            MetricCard(title: "FPS", value: String(format: "%.0f", snap.captureFPS), unit: "fps", accent: .haloSuccess, icon: "speedometer")
            MetricCard(title: "Latency", value: String(format: "%.1f", snap.totalLatencyMs), unit: "ms", accent: .haloPrimary, icon: "timer")
            MetricCard(title: "GPU", value: String(format: "%.1f", snap.gpuProcessingMs), unit: "ms", accent: .haloAccent, icon: "cpu")
        }
    }
}

// MARK: - ModeTile

struct ModeTile: View {
    let mode: AmbientMode
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: mode.symbolName)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.haloPrimary : .secondary)
                    .frame(height: 28)

                Text(mode.displayName)
                    .font(Typography.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(isSelected
                          ? Color.haloPrimary.opacity(0.15)
                          : isHovered ? Color.white.opacity(0.06) : Color.haloCard.opacity(0.5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .strokeBorder(isSelected ? Color.haloPrimary.opacity(0.5) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(Anim.snap, value: isSelected)
        .animation(Anim.micro, value: isHovered)
    }
}

// MARK: - Preview

#Preview {
    let env = AppEnvironment()
    ContentView()
        .environmentObject(env)
        .environmentObject(env.settings)
        .environmentObject(env.controllerMonitor)
        .environmentObject(env.effectsEngine)
        .environmentObject(env.diagnostics)
        .frame(width: 900, height: 620)
}
