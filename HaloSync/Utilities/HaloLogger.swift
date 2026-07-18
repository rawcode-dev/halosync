// HaloSync — Utilities/HaloLogger.swift
// Structured logging using OSLog.
// Each subsystem gets its own Logger category for granular filtering in Console.app.

import OSLog
import Foundation

/// Centralized structured logger for HaloSync.
/// Usage:  HaloLogger.capture.debug("Frame received: \(frameID)")
public enum HaloLogger {
    private static let subsystem = "com.halosync.app"

    // MARK: - Categories

    /// Screen capture pipeline events.
    public static let capture    = Logger(subsystem: subsystem, category: "Capture")

    /// Metal GPU processing events.
    public static let metal      = Logger(subsystem: subsystem, category: "Metal")

    /// Fluid engine smoothing events.
    public static let fluid      = Logger(subsystem: subsystem, category: "FluidEngine")

    /// Controller networking events.
    public static let network    = Logger(subsystem: subsystem, category: "Network")

    /// mDNS / IP discovery events.
    public static let discovery  = Logger(subsystem: subsystem, category: "Discovery")

    /// Effects engine events.
    public static let effects    = Logger(subsystem: subsystem, category: "Effects")

    /// Calibration events.
    public static let calibration = Logger(subsystem: subsystem, category: "Calibration")

    /// Profile persistence events.
    public static let profiles   = Logger(subsystem: subsystem, category: "Profiles")

    /// General application lifecycle events.
    public static let app        = Logger(subsystem: subsystem, category: "App")

    /// UI / ViewModel events.
    public static let ui         = Logger(subsystem: subsystem, category: "UI")

    /// Diagnostics and metrics.
    public static let diagnostics = Logger(subsystem: subsystem, category: "Diagnostics")
}

// MARK: - Performance Logging Helper

/// Measures and logs the duration of a synchronous block.
/// - Parameters:
///   - label: Log label (compiled out in release if using OSLog privacy).
///   - logger: The Logger instance to use.
///   - threshold: Only log if duration exceeds this (avoids log spam).
///   - block: The work to measure.
@discardableResult
public func measurePerformance<T>(
    label: String,
    logger: Logger = HaloLogger.app,
    threshold: Duration = .milliseconds(5),
    block: () throws -> T
) rethrows -> T {
    let start = ContinuousClock.now
    let result = try block()
    let elapsed = ContinuousClock.now - start
    if elapsed > threshold {
        logger.debug("\(label) took \(elapsed, privacy: .public)")
    }
    return result
}
