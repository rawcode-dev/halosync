// HaloSync — UI/Components/StatusBadge.swift
// Animated status pill that shows connection state with color + icon.

import SwiftUI

// MARK: - StatusBadge

/// Animated connection status indicator.
/// Shows pulsing dot animation when connecting.
struct StatusBadge: View {
    let status: ConnectionStatus
    var showLabel: Bool = true

    private var color: Color {
        switch status {
        case .connected:    return .haloSuccess
        case .connecting:   return .haloWarning
        case .disconnected: return Color(white: 0.5)
        case .error:        return .haloError
        }
    }

    @State private var pulse = false

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ZStack {
                if status == .connecting {
                    Circle()
                        .fill(color.opacity(0.35))
                        .frame(width: 16, height: 16)
                        .scaleEffect(pulse ? 1.6 : 1.0)
                        .opacity(pulse ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                            value: pulse
                        )
                }
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }

            if showLabel {
                Text(status.rawValue)
                    .font(Typography.captionMed)
                    .foregroundStyle(color)
            }
        }
        .onAppear { pulse = true }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        StatusBadge(status: .connected)
        StatusBadge(status: .connecting)
        StatusBadge(status: .disconnected)
        StatusBadge(status: .error)
    }
    .padding()
}
