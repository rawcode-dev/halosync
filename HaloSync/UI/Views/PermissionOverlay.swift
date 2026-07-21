// HaloSync — UI/Views/PermissionOverlay.swift
// A prominent overlay shown when Screen Recording permission is missing.

import SwiftUI

struct PermissionOverlay: View {
    @EnvironmentObject private var env: AppEnvironment
    
    var body: some View {
        ZStack {
            // Blurred background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: Spacing.xl) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.haloPrimary.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "lock.display")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.haloPrimary)
                }
                
                // Text
                VStack(spacing: Spacing.sm) {
                    Text("Screen Recording Access Required")
                        .font(Typography.title)
                        .foregroundStyle(.primary)
                    
                    Text("HaloSync needs permission to analyze your screen in order to sync colors to your lights. macOS only asks for this once.")
                        .font(Typography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
                
                // Actions
                VStack(spacing: Spacing.md) {
                    Button(action: {
                        PermissionHandler.openSystemSettings()
                    }) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "gearshape.fill")
                            Text("Open System Settings")
                        }
                        .font(Typography.bodyMedium)
                        .foregroundStyle(.white)
                        .padding(.vertical, Spacing.sm)
                        .padding(.horizontal, Spacing.lg)
                        .background(Color.haloPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        Task { await env.checkPermission() }
                    }) {
                        Text("I've granted access")
                            .font(Typography.bodyMedium)
                            .foregroundStyle(.primary)
                            .padding(.vertical, Spacing.sm)
                            .padding(.horizontal, Spacing.lg)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(Color.haloBackground)
                    .shadow(color: .black.opacity(0.4), radius: 30, y: 15)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}
