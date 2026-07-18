// HaloSync — UI/Views/EffectsView.swift
// Effect browser and selector.
// Each effect shown as a preview card with animated color swatch.

import SwiftUI

struct EffectsView: View {
    @EnvironmentObject private var effectsEngine: EffectsEngine
    @EnvironmentObject private var settings: HaloSyncSettingsStore
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var pipeline: AmbientPipeline

    @State private var time: Double = 0
    private let timer = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Effects")
                        .font(Typography.title)
                    Text("Choose a standalone lighting effect")
                        .font(Typography.body)
                        .foregroundStyle(.secondary)
                }

                if settings.value.activeMode != .effects {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("Screen Sync is currently active. Selecting an effect will override it.")
                            .font(Typography.bodyMedium)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.haloCard)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1)
                    )
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.md), count: 3),
                    spacing: Spacing.md
                ) {
                    ForEach(EffectsEngine.allEffects, id: \.id) { effect in
                        EffectCard(
                            effect: effect,
                            time: time,
                            isSelected: settings.value.activeMode == .effects && settings.value.activeEffectID == effect.id
                        ) {
                            withAnimation(Anim.snap) {
                                settings.value.activeMode = .effects
                                settings.value.activeEffectID = effect.id
                            }
                            if !pipeline.isRunning {
                                Task { await env.startPipeline() }
                            }
                        }
                    }
                }
            }
            .padding(Spacing.xl)
        }
        .navigationTitle("Effects")
        .onReceive(timer) { _ in time += 1.0/60.0 }
    }
}

// MARK: - EffectCard

struct EffectCard: View {
    let effect: any AmbientEffectProtocol
    let time: Double
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var previewColors: [Color] {
        let frame = effect.next(ledCount: 24, time: time, brightness: 1.0)
        return frame.colors.map { $0.swiftUIColor }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Animated color preview strip
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        ForEach(Array(previewColors.enumerated()), id: \.offset) { _, color in
                            Rectangle()
                                .fill(color)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                }
                .frame(height: 56)

                HStack {
                    Image(systemName: effect.symbolName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? .haloPrimary : .secondary)
                    Text(effect.name)
                        .font(Typography.bodyMedium)
                        .foregroundStyle(isSelected ? .primary : .secondary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.haloPrimary)
                    }
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(isSelected ? Color.haloPrimary.opacity(0.12) : Color.haloCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .strokeBorder(isSelected ? Color.haloPrimary.opacity(0.5) : Color.haloBorder, lineWidth: 1.5)
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(Anim.snap, value: isHovered)
        .animation(Anim.snap, value: isSelected)
    }
}
