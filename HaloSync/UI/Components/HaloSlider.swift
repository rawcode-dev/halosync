// HaloSync — UI/Components/HaloSlider.swift
// Premium custom slider with gradient track, animated thumb, and live value label.

import SwiftUI

// MARK: - HaloSlider

/// Branded slider with gradient track and animated hover state.
struct HaloSlider: View {
    let title: String
    @Binding var value: Float
    var range: ClosedRange<Float> = 0...1
    var accentColors: [Color] = [.haloPrimary, .haloAccent]
    var formatValue: (Float) -> String = { "\(Int($0 * 100))%" }
    var icon: String? = nil

    @State private var isDragging = false

    var body: some View {
        VStack(spacing: Spacing.xs) {
            HStack {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text(title)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(.primary)
                Spacer()
                Text(formatValue(value))
                    .font(Typography.monoMedium)
                    .foregroundStyle(.haloPrimary)
                    .contentTransition(.numericText())
                    .animation(Anim.micro, value: value)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.haloBorder)
                        .frame(width: proxy.size.width, height: 6)

                    // Filled portion
                    let percentage = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: accentColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(0, proxy.size.width * percentage),
                            height: 6
                        )
                        .animation(Anim.snap, value: value)

                    // Interaction layer
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    if !isDragging {
                                        withAnimation(Anim.snap) { isDragging = true }
                                    }
                                    let percentage = max(0, min(1, drag.location.x / proxy.size.width))
                                    let newValue = range.lowerBound + Float(percentage) * (range.upperBound - range.lowerBound)
                                    value = newValue
                                }
                                .onEnded { _ in
                                    withAnimation(Anim.snap) { isDragging = false }
                                }
                        )
                }
                .frame(height: proxy.size.height, alignment: .center)
            }
            .frame(height: 24) // Fixed height to prevent layout invalidation during drag
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var brightness: Float = 0.8
    @Previewable @State var smoothness: Float = 0.55

    VStack(spacing: 24) {
        HaloSlider(title: "Brightness", value: $brightness, icon: "sun.max.fill")
        HaloSlider(title: "Smoothness", value: $smoothness, accentColors: [.haloAccent, .haloPrimary], icon: "drop.fill")
    }
    .padding()
    .background(Color.haloBackground)
}
