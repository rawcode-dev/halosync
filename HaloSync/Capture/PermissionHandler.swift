// HaloSync — Capture/PermissionHandler.swift
// Manages ScreenCaptureKit permissions in a clean, async API.
// The first-launch experience hinges on this being frictionless.

import ScreenCaptureKit
import CoreGraphics
import Foundation

// MARK: - PermissionStatus

public enum PermissionStatus: Sendable {
    case granted
    case denied
}

// MARK: - PermissionHandler

/// Checks and requests Screen Recording permission.
/// Design goal: single async call, UI only shown once, never blocked.
public final class PermissionHandler: Sendable {

    public init() {}

    // MARK: - Public API

    /// Checks the current Screen Recording permission status without triggering a prompt.
    public func checkStatus() -> PermissionStatus {
        if CGPreflightScreenCaptureAccess() {
            return .granted
        }
        return .denied
    }

    /// Requests Screen Recording permission.
    /// On first call, macOS presents the system prompt.
    /// Subsequent calls return immediately with the cached decision.
    /// - Returns: The resulting `PermissionStatus`.
    @discardableResult
    public func requestPermission() async -> PermissionStatus {
        let granted = CGRequestScreenCaptureAccess()
        return granted ? .granted : .denied
    }
}
