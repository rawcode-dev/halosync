// HaloSync — Layout/Mappers/CoordinateMapper.swift
// Generates Metal GPU coordinates natively from a CustomLayout config.

import Foundation
import simd

public struct CoordinateMapper {
    
    public init() {}
    
    /// Maps a 9-segment layout into raw 2D Metal coordinates, ensuring safe buffer bounds.
    public func map(layout: CustomLayout, totalLeds: Int, cropTop: Float = 0.0, cropBottom: Float = 0.0, cropLeft: Float = 0.0, cropRight: Float = 0.0) -> [simd_float2] {
        var coordinates: [simd_float2] = []
        coordinates.reserveCapacity(layout.totalLEDs)
        
        let minX = max(0.0, min(1.0, cropLeft))
        let maxX = max(0.0, min(1.0, 1.0 - cropRight))
        let minY = max(0.0, min(1.0, cropTop))
        let maxY = max(0.0, min(1.0, 1.0 - cropBottom))
        
        // Define exact corner and edge anchors
        let TL = simd_float2(minX, minY)
        let TR = simd_float2(maxX, minY)
        let BR = simd_float2(maxX, maxY)
        let BL = simd_float2(minX, maxY)
        let BC = simd_float2(minX + (maxX - minX) / 2.0, maxY)
        
        // Helper to interpolate between two anchors
        func appendSegment(count: Int, start: simd_float2, end: simd_float2) {
            guard count > 0 else { return }
            if count == 1 {
                coordinates.append(start)
                return
            }
            for i in 0..<count {
                let fraction = Float(i) / Float(count - 1)
                let x = start.x + (end.x - start.x) * fraction
                let y = start.y + (end.y - start.y) * fraction
                coordinates.append(simd_float2(x, y))
            }
        }
        
        // Generate in physical sequence
        appendSegment(count: layout.bottomLeft,        start: BC, end: BL)
        appendSegment(count: layout.bottomLeftCorner,  start: BL, end: BL)
        appendSegment(count: layout.left,              start: BL, end: TL)
        appendSegment(count: layout.topLeftCorner,     start: TL, end: TL)
        appendSegment(count: layout.top,               start: TL, end: TR)
        appendSegment(count: layout.topRightCorner,    start: TR, end: TR)
        appendSegment(count: layout.right,             start: TR, end: BR)
        appendSegment(count: layout.bottomRightCorner, start: BR, end: BR)
        appendSegment(count: layout.bottomRight,       start: BR, end: BC)
        
        // Safety: Ensure exactly `totalLeds` coordinates to prevent Metal GPU bounds crashes
        if coordinates.count > totalLeds {
            coordinates = Array(coordinates.prefix(totalLeds))
        } else {
            while coordinates.count < totalLeds {
                coordinates.append(coordinates.last ?? BC) // pad with last position
            }
        }
        
        return coordinates
    }
}
