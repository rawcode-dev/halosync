import Foundation
import simd

let validYAML = """
version: 1
layout:
  name: "MSI G274QPF"
  monitor:
    aspectRatio: "16:9"
strip:
  totalLeds: 111
  start:
    led: 0
    edge: bottom
    anchor: center
  direction: counter_clockwise
segments:
  - id: bottom_left
    type: edge
    from: bottom_center
    to: bottom_left_corner
    leds: 17
  - id: bottom_left_corner
    type: corner
    leds: 1
  - id: left
    type: edge
    from: bottom_left_corner
    to: top_left_corner
    leds: 20
  - id: top_left_corner
    type: corner
    leds: 1
  - id: top
    type: edge
    from: top_left_corner
    to: top_right_corner
    leds: 35
  - id: top_right_corner
    type: corner
    leds: 1
  - id: right
    type: edge
    from: top_right_corner
    to: bottom_right_corner
    leds: 20
  - id: bottom_right_corner
    type: corner
    leds: 1
  - id: bottom_right
    type: edge
    from: bottom_right_corner
    to: bottom_center
    leds: 16
"""

// Wait, since I'm running this script outside the app, I can't easily import LayoutEngine from the Xcode project unless I compile it or use it as a package. 
// I'll just print out the coordinates to manually verify the logic.

let TL = simd_float2(0.0, 0.0)
let TR = simd_float2(1.0, 0.0)
let BR = simd_float2(1.0, 1.0)
let BL = simd_float2(0.0, 1.0)
let BC = simd_float2(0.5, 1.0)

var current = 0
func printSegment(id: String, leds: Int, start: simd_float2, end: simd_float2) {
    if leds == 1 {
        print("LED \(current): [\(start.x), \(start.y)] - \(id)")
        current += 1
        return
    }
    for i in 0..<leds {
        let fraction = Float(i) / Float(leds - 1)
        let x = start.x + (end.x - start.x) * fraction
        let y = start.y + (end.y - start.y) * fraction
        
        let formattedX = String(format: "%.3f", x)
        let formattedY = String(format: "%.3f", y)
        print("LED \(current): [\(formattedX), \(formattedY)] - \(id) (\(i+1)/\(leds))")
        current += 1
    }
}

print("LOOKUP TABLE:")
printSegment(id: "Bottom Left", leds: 17, start: BC, end: BL)
printSegment(id: "Bottom Left Corner", leds: 1, start: BL, end: BL)
printSegment(id: "Left Edge", leds: 20, start: BL, end: TL)
printSegment(id: "Top Left Corner", leds: 1, start: TL, end: TL)
printSegment(id: "Top Edge", leds: 35, start: TL, end: TR)
printSegment(id: "Top Right Corner", leds: 1, start: TR, end: TR)
printSegment(id: "Right Edge", leds: 20, start: TR, end: BR)
printSegment(id: "Bottom Right Corner", leds: 1, start: BR, end: BR)
printSegment(id: "Bottom Right", leds: 16, start: BR, end: BC)
