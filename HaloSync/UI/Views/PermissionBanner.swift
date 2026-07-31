// HaloSync — UI/Views/PermissionBanner.swift
// A prominent banner shown when Screen Recording permission is missing.

import SwiftUI

struct PermissionBanner: View {
    @EnvironmentObject private var env: AppEnvironment
    
    var body: some View {
        GlassCard {
            HStack(spacing: Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.haloPrimary.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "lock.display.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.haloPrimary)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text("Screen Recording Access Required")
                        .font(Typography.headline)
                        .foregroundStyle(.primary)
                    
                    Text("HaloSync needs permission to analyze your screen for Screen Sync.")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Actions
                VStack(spacing: Spacing.sm) {
                    Button(action: {
                        PermissionHandler.openSystemSettings()
                    }) {
                        Text("Get Access")
                            .font(Typography.captionMed)
                            .foregroundStyle(.white)
                            .padding(.vertical, Spacing.xs)
                            .padding(.horizontal, Spacing.md)
                            .background(Color.haloPrimary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        Task { await env.checkPermission() }
                    }) {
                        Text("I've granted access")
                            .font(Typography.micro)
                            .foregroundStyle(.secondary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .strokeBorder(Color.haloPrimary.opacity(0.3), lineWidth: 1)
        )
    }
}
