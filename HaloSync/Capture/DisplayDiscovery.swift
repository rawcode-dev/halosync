// HaloSync — Capture/DisplayDiscovery.swift
// Discovers all connected displays using CoreGraphics and caches their DisplayInfo.
// Listens for display configuration changes to auto-update the list.

import Foundation
import CoreGraphics

// MARK: - DisplayDiscovery

/// Discovers and monitors all connected macOS displays.
/// Fires notifications via `AsyncStream` whenever the display configuration changes.
public final class DisplayDiscovery: Sendable {

    // MARK: - Init

    public init() {}

    // MARK: - Public API

    /// Returns the current list of all active displays.
    public func currentDisplays() -> [DisplayInfo] {
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 32)
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(32, &displayIDs, &displayCount)
        return displayIDs
            .prefix(Int(displayCount))
            .compactMap { makeDisplayInfo(for: $0) }
    }

    /// Streams display configuration change events.
    /// Fires immediately with the current display list, then on every change.
    public func displayChanges() -> AsyncStream<[DisplayInfo]> {
        let (stream, continuation) = AsyncStream<[DisplayInfo]>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )

        // Emit current state immediately.
        continuation.yield(currentDisplays())

        // Register for display reconfiguration callbacks.
        // Note: CGDisplayRegisterReconfigurationCallback requires a C function or
        // a static context. We use NotificationCenter + a polling heartbeat as a
        // clean Swift-native alternative.
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            var lastDisplayIDs = Set(self.currentDisplays().map { $0.displayID })
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                let current = self.currentDisplays()
                let currentIDs = Set(current.map { $0.displayID })
                if currentIDs != lastDisplayIDs {
                    continuation.yield(current)
                    lastDisplayIDs = currentIDs
                }
            }
            continuation.finish()
        }

        return stream
    }

    // MARK: - Private

    private func makeDisplayInfo(for displayID: CGDirectDisplayID) -> DisplayInfo? {
        guard CGDisplayIsActive(displayID) != 0 else { return nil }

        let width  = CGDisplayPixelsWide(displayID)
        let height = CGDisplayPixelsHigh(displayID)
        guard width > 0, height > 0 else { return nil }

        let uuid = "display-\(displayID)"

        let mode       = CGDisplayCopyDisplayMode(displayID)
        let refreshRate = mode?.refreshRate ?? 60.0
        let scaleFactor: Double = CGDisplayIsInHWMirrorSet(displayID) != 0 ? 1.0 : {
            let physWidth  = CGDisplayScreenSize(displayID).width
            let logWidth   = Double(width)
            return logWidth / max(physWidth, 1) > 10 ? 2.0 : 1.0
        }()
        let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0
        let isMain    = CGDisplayIsMain(displayID)    != 0

        let name = displayName(for: displayID, isBuiltIn: isBuiltIn)

        return DisplayInfo(
            uuid:        uuid,
            displayID:   displayID,
            name:        name,
            resolution:  CGSize(width: width, height: height),
            refreshRate: refreshRate,
            scaleFactor: scaleFactor,
            isBuiltIn:   isBuiltIn,
            isMain:      isMain
        )
    }

    private func displayName(for displayID: CGDirectDisplayID, isBuiltIn: Bool) -> String {
        // On Apple Silicon, CoreGraphics doesn't expose display names directly.
        // We fall back to a friendly label based on built-in status and display number.
        if isBuiltIn {
            return "Built-in Retina Display"
        }
        // TODO: Phase 6 — use IOKit to read the monitor EDID name.
        return "External Display"
    }
}
