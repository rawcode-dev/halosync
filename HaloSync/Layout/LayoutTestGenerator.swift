// HaloSync — Layout/LayoutTestGenerator.swift
// Generates distinct colors for each physical segment to verify layout mappings.

import Foundation

public struct LayoutTestGenerator {
    
    /// Distinct test colors for each segment
    public static let colors: [String: LEDColor] = [
        "bottomLeft":        LEDColor(red: 1.0, green: 0.0, blue: 0.0), // Red
        "bottomLeftCorner":  LEDColor(red: 1.0, green: 1.0, blue: 1.0), // White
        "left":              LEDColor(red: 0.0, green: 1.0, blue: 0.0), // Green
        "topLeftCorner":     LEDColor(red: 1.0, green: 1.0, blue: 1.0), // White
        "top":               LEDColor(red: 0.0, green: 0.0, blue: 1.0), // Blue
        "topRightCorner":    LEDColor(red: 1.0, green: 1.0, blue: 1.0), // White
        "right":             LEDColor(red: 1.0, green: 1.0, blue: 0.0), // Yellow
        "bottomRightCorner": LEDColor(red: 1.0, green: 1.0, blue: 1.0), // White
        "bottomRight":       LEDColor(red: 0.0, green: 1.0, blue: 1.0)  // Cyan
    ]
    
    /// Generates a frame of test colors mapping exactly to the layout configuration
    public static func generate(layout: CustomLayout, totalLeds: Int) -> [LEDColor] {
        var testFrame: [LEDColor] = []
        testFrame.reserveCapacity(layout.totalLEDs)
        
        func appendSegment(count: Int, color: LEDColor) {
            guard count > 0 else { return }
            testFrame.append(contentsOf: Array(repeating: color, count: count))
        }
        
        appendSegment(count: layout.bottomLeft,        color: colors["bottomLeft"]!)
        appendSegment(count: layout.bottomLeftCorner,  color: colors["bottomLeftCorner"]!)
        appendSegment(count: layout.left,              color: colors["left"]!)
        appendSegment(count: layout.topLeftCorner,     color: colors["topLeftCorner"]!)
        appendSegment(count: layout.top,               color: colors["top"]!)
        appendSegment(count: layout.topRightCorner,    color: colors["topRightCorner"]!)
        appendSegment(count: layout.right,             color: colors["right"]!)
        appendSegment(count: layout.bottomRightCorner, color: colors["bottomRightCorner"]!)
        appendSegment(count: layout.bottomRight,       color: colors["bottomRight"]!)
        
        // Safety bounds
        if testFrame.count > totalLeds {
            testFrame = Array(testFrame.prefix(totalLeds))
        } else {
            while testFrame.count < totalLeds {
                testFrame.append(LEDColor.black)
            }
        }
        
        return testFrame
    }
}
