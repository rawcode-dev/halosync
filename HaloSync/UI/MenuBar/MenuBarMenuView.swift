// HaloSync — UI/MenuBar/MenuBarMenuView.swift
// Compact menu bar popover for quick controls without opening the main window.

import SwiftUI

struct MenuBarMenuView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var settings: HaloSyncSettingsStore
    @EnvironmentObject private var monitor: ControllerMonitor

    @State private var isRunning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "light.ribbon")
                    .foregroundStyle(
                        LinearGradient(colors: [.haloPrimary, .haloAccent], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Text("HaloSync")
                    .font(.headline)
                Spacer()
                StatusBadge(status: monitor.discoveredDevice?.connectionStatus ?? .disconnected, showLabel: false)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Quick Controls
            VStack(spacing: 4) {
                menuSlider("Brightness", value: $settings.value.brightness, icon: "sun.max.fill")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Mode
            Text("Mode".uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            ForEach([AmbientMode.ambient, .movie, .gaming, .desktop, .night]) { mode in
                Button {
                    settings.value.activeMode = mode
                } label: {
                    HStack {
                        Image(systemName: mode.symbolName)
                            .frame(width: 16)
                        Text(mode.displayName)
                        Spacer()
                        if settings.value.activeMode == mode {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.haloPrimary)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)

            Divider()

            // Actions
            Button(isRunning ? "Stop Lighting" : "Start Lighting") {
                isRunning.toggle()
            }

            Button("Open HaloSync") {
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button("Quit HaloSync") {
                NSApp.terminate(nil)
            }
        }
        .frame(width: 260)
    }

    private func menuSlider(_ label: String, value: Binding<Float>, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Slider(value: value)
                .tint(.haloPrimary)
            Text("\(Int(value.wrappedValue * 100))%")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}
