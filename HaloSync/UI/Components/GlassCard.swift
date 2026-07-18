// HaloSync — UI/Components/GlassCard.swift
// Premium glassmorphism card container used throughout the UI.
// Adapts to dark/light mode automatically.

import SwiftUI

// MARK: - GlassCard

/// A frosted glass card with subtle border and shadow.
/// Used as the primary container for all content panels in HaloSync.
struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = Spacing.lg
    var cornerRadius: CGFloat = Radius.lg

    init(padding: CGFloat = Spacing.lg, cornerRadius: CGFloat = Radius.lg, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.15), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .haloShadow(Shadow.md)
    }
}

// MARK: - PrimaryCard

/// Opaque dark card for content that needs strong contrast.
struct PrimaryCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = Spacing.lg
    var cornerRadius: CGFloat = Radius.lg

    init(padding: CGFloat = Spacing.lg, cornerRadius: CGFloat = Radius.lg, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.haloCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.haloBorder, lineWidth: 1)
                    )
            )
            .haloShadow(Shadow.sm)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.haloBackground.ignoresSafeArea()
        GlassCard {
            Text("HaloSync Card")
                .font(Typography.headline)
                .foregroundStyle(.primary)
        }
        .padding()
    }
}
