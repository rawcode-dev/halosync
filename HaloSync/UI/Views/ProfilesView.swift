// HaloSync — UI/Views/ProfilesView.swift
// Browse, create, and apply user profiles.

import SwiftUI

struct ProfilesView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var settings: HaloSyncSettingsStore
    @State private var profiles: [Profile] = []
    @State private var showNewProfile = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Profiles")
                            .font(Typography.title)
                        Text("Quickly switch between saved configurations")
                            .font(Typography.body)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        showNewProfile = true
                    } label: {
                        Label("New Profile", systemImage: "plus")
                            .font(Typography.bodyMedium)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                Capsule()
                                    .fill(Color.haloPrimary.opacity(0.15))
                                    .overlay(Capsule().strokeBorder(Color.haloPrimary.opacity(0.4)))
                            )
                            .foregroundStyle(.haloPrimary)
                    }
                    .buttonStyle(.plain)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.md), count: 2),
                    spacing: Spacing.md
                ) {
                    ForEach(profiles) { profile in
                        ProfileCard(
                            profile: profile,
                            isActive: settings.value.activeProfileID == profile.id
                        ) {
                            applyProfile(profile)
                        }
                    }
                }
            }
            .padding(Spacing.xl)
        }
        .navigationTitle("Profiles")
        .onAppear { profiles = env.profileStore.listAll() }
    }

    private func applyProfile(_ profile: Profile) {
        withAnimation(Anim.snap) {
            settings.value.brightness      = profile.brightness
            settings.value.smoothness      = profile.smoothness
            settings.value.ambientStrength = profile.ambientStrength
            settings.value.activeMode      = profile.mode
            settings.value.activeProfileID = profile.id
        }
    }
}

// MARK: - ProfileCard

struct ProfileCard: View {
    let profile: Profile
    let isActive: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    private var accent: Color { Color(hex: profile.colorAccent) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: profile.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack {
                        Text(profile.name)
                            .font(Typography.headline)
                            .foregroundStyle(.primary)
                        if profile.isBuiltIn {
                            Text("BUILT-IN")
                                .font(Typography.micro)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.haloBorder))
                        }
                    }
                    Text(profile.mode.displayName)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: Spacing.xs) {
                        paramChip("Brightness", "\(Int(profile.brightness * 100))%")
                        paramChip("Smooth", "\(Int(profile.smoothness * 100))%")
                    }
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(accent)
                }
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(isActive ? accent.opacity(0.10) : Color.haloCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .strokeBorder(isActive ? accent.opacity(0.5) : Color.haloBorder, lineWidth: 1.5)
                    )
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(Anim.snap, value: isHovered)
        .animation(Anim.snap, value: isActive)
    }

    private func paramChip(_ label: String, _ value: String) -> some View {
        Text("\(label): \(value)")
            .font(Typography.micro)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.haloBorder.opacity(0.5)))
    }
}
