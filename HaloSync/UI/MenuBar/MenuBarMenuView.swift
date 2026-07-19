// HaloSync — UI/MenuBar/MenuBarMenuView.swift
// Compact menu bar popover for quick controls without opening the main window.

import SwiftUI

struct MenuBarMenuView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var settings: HaloSyncSettingsStore
    @EnvironmentObject private var monitor: ControllerMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "light.ribbon")
                    .foregroundStyle(
                        LinearGradient(colors: [.haloPrimary, .haloAccent], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .font(.title2)
                Text("HaloSync")
                    .font(.headline)
                Spacer()
                StatusBadge(status: monitor.discoveredDevice?.connectionStatus ?? .disconnected, showLabel: false)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Quick Controls
            VStack(spacing: 8) {
                menuSlider("Brightness", value: $settings.value.brightness, icon: "sun.max.fill")
                    .disabled(settings.value.activeMode != .custom)
                    .opacity(settings.value.activeMode != .custom ? 0.5 : 1.0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Mode
            Text("MODE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)

            VStack(spacing: 2) {
                ForEach([AmbientMode.ambient, .movie, .gaming, .desktop, .night]) { mode in
                    Button {
                        settings.value.activeMode = mode
                        if mode != .custom {
                            let defaults = mode.defaultParameters
                            settings.value.brightness = defaults.brightness
                            settings.value.smoothness = defaults.smoothness
                            settings.value.ambientStrength = defaults.ambientStrength
                        }
                    } label: {
                        HStack {
                            Image(systemName: mode.symbolName)
                                .frame(width: 20)
                            Text(mode.displayName)
                            Spacer()
                            if settings.value.activeMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.haloPrimary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 8)

            Divider()

            // Actions
            VStack(spacing: 12) {
                Button {
                    Task {
                        if env.pipeline.isRunning {
                            await env.stopPipeline()
                        } else {
                            await env.startPipeline()
                        }
                    }
                } label: {
                    Text(env.pipeline.isRunning ? "Stop Syncing" : "Start Syncing")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(env.pipeline.isRunning ? .red : .haloPrimary)

                HStack(spacing: 8) {
                    Button {
                        NSApp.activate(ignoringOtherApps: true)
                    } label: {
                        Text("Open App")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        NSApp.terminate(nil)
                    } label: {
                        Text("Quit")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(16)
        }
        .frame(width: 260)
        .background(Material.ultraThinMaterial)
    }

    private func menuSlider(_ label: String, value: Binding<Float>, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Slider(value: value)
                .tint(.haloPrimary)
            Text("\(Int(value.wrappedValue * 100))%")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}
