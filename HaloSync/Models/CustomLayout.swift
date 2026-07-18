// HaloSync — Models/CustomLayout.swift
// User-configured LED counts for each standard physical segment.
// Used to natively generate coordinates without requiring YAML mapping.

import Foundation

public struct CustomLayout: Codable, Equatable, Sendable {
    
    // Bottom edge (split for bottom-center starts)
    public var bottomLeft: Int = 17
    public var bottomLeftCorner: Int = 1
    
    // Left edge
    public var left: Int = 20
    public var topLeftCorner: Int = 1
    
    // Top edge
    public var top: Int = 35
    public var topRightCorner: Int = 1
    
    // Right edge
    public var right: Int = 20
    public var bottomRightCorner: Int = 1
    
    // Bottom edge returning to center
    public var bottomRight: Int = 16
    
    public init() {}
    
    public var totalLEDs: Int {
        bottomLeft + bottomLeftCorner +
        left + topLeftCorner +
        top + topRightCorner +
        right + bottomRightCorner +
        bottomRight
    }
}
