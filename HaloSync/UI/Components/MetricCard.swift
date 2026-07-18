// HaloSync — UI/Components/MetricCard.swift
// Compact metric display card for the Diagnostics view and Home status row.

import SwiftUI

// MARK: - MetricCard

/// Displays a single labeled metric value in a compact card.
struct MetricCard: View {
    let title: String
    let value: String
    let unit:  String
    var accent: Color = .haloPrimary
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accent)
                }
                Text(title.uppercased())
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
            }

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                Text(unit)
                    .font(Typography.captionMed)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.haloCard)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(accent.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        MetricCard(title: "FPS", value: "120", unit: "fps", accent: .haloSuccess, icon: "speedometer")
        MetricCard(title: "Latency", value: "4.2", unit: "ms", accent: .haloPrimary, icon: "timer")
        MetricCard(title: "GPU", value: "2.1", unit: "%", accent: .haloAccent, icon: "cpu")
    }
    .padding()
    .background(Color.haloBackground)
}
