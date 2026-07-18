// HaloSync — UI/Views/LayoutPreviewView.swift
// Visualizes the physical LED layout based on the CustomLayout settings.

import SwiftUI

struct LayoutPreviewView: View {
    let layout: CustomLayout
    let previewImage: CGImage?
    let showLivePreview: Bool
    
    let cropTop: Float
    let cropBottom: Float
    let cropLeft: Float
    let cropRight: Float
    
    var body: some View {
        GeometryReader { proxy in
            // Force a 16:9 aspect ratio inside the geometry proxy
            let targetAspect: CGFloat = 16.0 / 9.0
            let containerW = proxy.size.width
            let containerH = proxy.size.height
            
            let displayW = min(containerW, containerH * targetAspect)
            let displayH = displayW / targetAspect
            let offsetX = (containerW - displayW) / 2
            let offsetY = (containerH - displayH) / 2
            
            ZStack {
                // Screen representation
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(Color(white: 0.15))
                    .overlay(
                        Group {
                            if showLivePreview, let cgImage = previewImage {
                                Image(cgImage, scale: 1.0, orientation: .up, label: Text("Screen Preview"))
                                    .resizable()
                                    .scaledToFill() // It will now fill a 16:9 box correctly!
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                                    .opacity(0.8)
                            } else {
                                Text("Screen")
                                    .font(Typography.bodyMedium)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .strokeBorder(Color(white: 0.3), lineWidth: 2)
                    )
                    .padding(16)
                
                // Edges (Inset slightly to sit outside the "Screen" padding but inside the view)
                let padding: CGFloat = 16
                let w = displayW - (padding * 2)
                let h = displayH - (padding * 2)
                
                // Apply User Crops (0.0 to 100.0) -> (0.0 to 1.0)
                let ct = CGFloat(max(0, min(100, cropTop))) / 100.0
                let cb = CGFloat(max(0, min(100, cropBottom))) / 100.0
                let cl = CGFloat(max(0, min(100, cropLeft))) / 100.0
                let cr = CGFloat(max(0, min(100, cropRight))) / 100.0
                
                let minX = padding + w * cl
                let maxX = padding + w * (1.0 - cr)
                let minY = padding + h * ct
                let maxY = padding + h * (1.0 - cb)
                
                let TL = CGPoint(x: minX, y: minY)
                let TR = CGPoint(x: maxX, y: minY)
                let BL = CGPoint(x: minX, y: maxY)
                let BR = CGPoint(x: maxX, y: maxY)
                let BC = CGPoint(x: minX + (maxX - minX) / 2.0, y: maxY)
                
                // Helpers
                let drawSegment = { (count: Int, color: LEDColor, start: CGPoint, end: CGPoint) -> AnyView in
                    if count <= 0 { return AnyView(EmptyView()) }
                    return AnyView(
                        ForEach(0..<count, id: \.self) { i in
                            let fraction = count > 1 ? CGFloat(i) / CGFloat(count - 1) : 0
                            let pos = CGPoint(x: start.x + (end.x - start.x) * fraction,
                                              y: start.y + (end.y - start.y) * fraction)
                            Circle()
                                .fill(Color(red: Double(color.red), green: Double(color.green), blue: Double(color.blue)))
                                .frame(width: 6, height: 6)
                                .position(pos)
                        }
                    )
                }
                
                // Draw physical sequence
                drawSegment(layout.bottomLeft,        LayoutTestGenerator.colors["bottomLeft"]!,        BC, BL)
                drawSegment(layout.bottomLeftCorner,  LayoutTestGenerator.colors["bottomLeftCorner"]!,  BL, BL)
                drawSegment(layout.left,              LayoutTestGenerator.colors["left"]!,              BL, TL)
                drawSegment(layout.topLeftCorner,     LayoutTestGenerator.colors["topLeftCorner"]!,     TL, TL)
                drawSegment(layout.top,               LayoutTestGenerator.colors["top"]!,               TL, TR)
                drawSegment(layout.topRightCorner,    LayoutTestGenerator.colors["topRightCorner"]!,    TR, TR)
                drawSegment(layout.right,             LayoutTestGenerator.colors["right"]!,             TR, BR)
                drawSegment(layout.bottomRightCorner, LayoutTestGenerator.colors["bottomRightCorner"]!, BR, BR)
                drawSegment(layout.bottomRight,       LayoutTestGenerator.colors["bottomRight"]!,       BR, BC)
            }
            .frame(width: displayW, height: displayH)
            .offset(x: offsetX, y: offsetY)
        }
    }
}
