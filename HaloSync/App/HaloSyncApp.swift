// HaloSync — App/HaloSyncApp.swift
// App entry point.
// Creates the AppEnvironment and injects it into the SwiftUI environment.
// Handles menu bar (NSStatusItem) and main window lifecycle.

import SwiftUI

@main
struct HaloSyncApp: App {

    // MARK: - State

    @StateObject private var env = AppEnvironment()

    // MARK: - Body

    var body: some Scene {
        // Main application window.
        WindowGroup {
            ContentView()
                .environmentObject(env)
                .environmentObject(env.settings)
                .environmentObject(env.controllerMonitor)
                .environmentObject(env.effectsEngine)
                .environmentObject(env.diagnostics)
                .environmentObject(env.pipeline)
                .frame(minWidth: 860, minHeight: 580)
                .task {
                    await env.startup()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            HaloSyncCommands()
        }

        // Menu Bar Extra (macOS 13+).
        MenuBarExtra("HaloSync", systemImage: "light.ribbon") {
            MenuBarMenuView()
                .environmentObject(env)
                .environmentObject(env.settings)
                .environmentObject(env.controllerMonitor)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - App Commands

struct HaloSyncCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About HaloSync") { }
        }
    }
}
