// HaloSync — UI/Views/ContentView.swift
// Root navigation container.
// Uses a sidebar + detail layout (NavigationSplitView) for a native macOS feel.

import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var selectedTab: Tab = .home

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $selectedTab)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
        } detail: {
            detail(for: selectedTab)
                .navigationSplitViewColumnWidth(min: 640, ideal: 860)
        }
        .background(Color.haloBackground)
    }

    @ViewBuilder
    private func detail(for tab: Tab) -> some View {
        switch tab {
        case .home:        HomeView()
        case .effects:     EffectsView()
        case .calibration: CalibrationView()
        case .diagnostics: DiagnosticsView()
        case .settings:    SettingsView()
        case .layout:      LayoutView()
        case .profiles:    ProfilesView()
        }
    }
}

// MARK: - Tab

enum Tab: String, CaseIterable, Identifiable {
    case home        = "Home"
    case effects     = "Effects"
    case calibration = "Calibration"
    case diagnostics = "Diagnostics"
    case layout      = "Layout"
    case profiles    = "Profiles"
    case settings    = "Settings"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .home:        return "house.fill"
        case .effects:     return "wand.and.stars"
        case .calibration: return "slider.horizontal.3"
        case .diagnostics: return "chart.xyaxis.line"
        case .layout:      return "rectangle.dashed"
        case .profiles:    return "person.2.square.stack.fill"
        case .settings:    return "gearshape.fill"
        }
    }
}

// MARK: - Sidebar

struct Sidebar: View {
    @Binding var selection: Tab
    @EnvironmentObject private var monitor: ControllerMonitor

    var body: some View {
        VStack(spacing: 0) {
            // App Brand Header
            HStack(spacing: Spacing.sm) {
                Image(systemName: "light.ribbon")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [.haloPrimary, .haloAccent], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Text("HaloSync")
                    .font(Typography.headline)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)

            Divider().opacity(0.3)

            // Navigation Items
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Tab.allCases) { tab in
                        SidebarItem(tab: tab, isSelected: selection == tab) {
                            withAnimation(Anim.snap) {
                                selection = tab
                            }
                        }
                    }
                }
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.sm)
            }

            Spacer()
            Divider().opacity(0.3)

            // Controller Status at Bottom
            if let device = monitor.discoveredDevice {
                ControllerStatusFooter(device: device)
            } else if monitor.isSearching {
                SearchingFooter()
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color.haloBackground.opacity(0.6))
    }
}

// MARK: - SidebarItem

struct SidebarItem: View {
    let tab: Tab
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: tab.symbolName)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.haloPrimary : .secondary)
                    .frame(width: 20)

                Text(tab.rawValue)
                    .font(isSelected ? Typography.bodyMedium : Typography.body)
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(isSelected
                          ? Color.haloPrimary.opacity(0.15)
                          : isHovered ? Color.white.opacity(0.06) : Color.clear
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(Anim.micro, value: isHovered)
        .animation(Anim.snap, value: isSelected)
    }
}

// MARK: - Controller Status Footer

struct ControllerStatusFooter: View {
    let device: DeviceInfo

    var body: some View {
        HStack(spacing: Spacing.sm) {
            StatusBadge(status: device.connectionStatus, showLabel: false)
            VStack(alignment: .leading, spacing: 1) {
                Text(device.name)
                    .font(Typography.captionMed)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(device.address)
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }
}

struct SearchingFooter: View {
    @State private var dots = ""
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView().scaleEffect(0.6)
            Text("Searching\(dots)")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .onReceive(timer) { _ in
            dots = dots.count >= 3 ? "" : dots + "."
        }
    }
}
