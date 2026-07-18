// HaloSync — Models/DisplayInfo.swift
// Represents a connected macOS display detected by CGDisplay / ScreenCaptureKit.
// UUID-based identity survives reboots and display reconnection events.

import Foundation
import CoreGraphics

/// A macOS display available for ambient capture.
public struct DisplayInfo: Sendable, Identifiable, Equatable, Codable {

    // MARK: - Identity

    /// Stable UUID for this display — survives reboots.
    public let uuid: String

    /// CGDirectDisplayID — volatile, changes at every boot or hotplug.
    /// Not stored persistently.
    public let displayID: CGDirectDisplayID

    public var id: String { uuid }

    // MARK: - Display Properties

    public let name: String
    public let resolution: CGSize
    public let refreshRate: Double          // Hz
    public let scaleFactor: Double          // 1.0 or 2.0 (Retina)
    public let isBuiltIn: Bool
    public let isMain: Bool

    // MARK: - Computed

    public var resolutionString: String {
        "\(Int(resolution.width))×\(Int(resolution.height))"
    }

    public var refreshRateString: String {
        refreshRate > 0 ? "\(Int(refreshRate)) Hz" : "–"
    }

    public var typeLabel: String {
        isBuiltIn ? "Built-in Display" : "External Display"
    }

    // MARK: - Init

    public init(
        uuid: String,
        displayID: CGDirectDisplayID,
        name: String,
        resolution: CGSize,
        refreshRate: Double,
        scaleFactor: Double,
        isBuiltIn: Bool,
        isMain: Bool
    ) {
        self.uuid        = uuid
        self.displayID   = displayID
        self.name        = name
        self.resolution  = resolution
        self.refreshRate = refreshRate
        self.scaleFactor = scaleFactor
        self.isBuiltIn   = isBuiltIn
        self.isMain      = isMain
    }
}
