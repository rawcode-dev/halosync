// HaloSync — UI/Views/LayoutView.swift
// Dedicated configuration screen for LED layouts.

import SwiftUI

struct LayoutView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var settings: HaloSyncSettingsStore
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("LED Mapping")
                        .font(Typography.display)
                    Text("Configure your physical LED layout starting from Bottom Center and moving counter-clockwise. Use the test toggle to preview the colors on your physical strip.")
                        .font(Typography.body)
                        .foregroundStyle(.secondary)
                }
                
                // Graphical Preview
                LayoutPreviewView(
                    layout: settings.value.layout,
                    previewImage: env.pipeline.previewImage,
                    showLivePreview: settings.value.showLivePreview,
                    cropTop: settings.value.cropTop,
                    cropBottom: settings.value.cropBottom,
                    cropLeft: settings.value.cropLeft,
                    cropRight: settings.value.cropRight
                )
                .frame(height: 250)
                .padding(.bottom, Spacing.md)
                
                // Tools
                HStack(spacing: Spacing.md) {
                    GlassCard {
                        Toggle("Show Live Preview", isOn: $settings.value.showLivePreview)
                            .font(Typography.bodyMedium)
                            .toggleStyle(SwitchToggleStyle(tint: .haloPrimary))
                    }
                    
                    GlassCard {
                        Toggle("Test on Hardware", isOn: $settings.value.isLayoutTestActive)
                            .font(Typography.bodyMedium)
                            .toggleStyle(SwitchToggleStyle(tint: .haloPrimary))
                    }
                }
                .padding(.bottom, Spacing.sm)
                
                // Screen Capture Config
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("CAPTURE BOUNDARIES")
                        .font(Typography.micro)
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                    
                    GlassCard {
                        VStack(spacing: Spacing.md) {
                            Toggle(isOn: $settings.value.blackBarDetection) {
                                VStack(alignment: .leading) {
                                    Text("Smart Black Bar Detection")
                                        .font(Typography.bodyMedium)
                                    Text("Automatically crops out cinematic letterbox/pillarbox borders")
                                        .font(Typography.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .haloPrimary))
                            
                            Divider().opacity(0.3)
                            
                            VStack(alignment: .leading, spacing: Spacing.md) {
                                Text("Manual Edge Crop")
                                    .font(Typography.bodyMedium)
                                    .opacity(settings.value.blackBarDetection ? 0.5 : 1.0)
                                Text("Set crop percentages (0-50%) to manually shrink the capture area.")
                                    .font(Typography.caption)
                                    .foregroundStyle(.secondary)
                                    .opacity(settings.value.blackBarDetection ? 0.5 : 1.0)
                                
                                HStack(spacing: Spacing.lg) {
                                    VStack {
                                        Text("Top: \(Int(settings.value.cropTop))%").font(Typography.caption)
                                        Slider(value: $settings.value.cropTop, in: 0...50, step: 1)
                                    }
                                    VStack {
                                        Text("Bottom: \(Int(settings.value.cropBottom))%").font(Typography.caption)
                                        Slider(value: $settings.value.cropBottom, in: 0...50, step: 1)
                                    }
                                }
                                HStack(spacing: Spacing.lg) {
                                    VStack {
                                        Text("Left: \(Int(settings.value.cropLeft))%").font(Typography.caption)
                                        Slider(value: $settings.value.cropLeft, in: 0...50, step: 1)
                                    }
                                    VStack {
                                        Text("Right: \(Int(settings.value.cropRight))%").font(Typography.caption)
                                        Slider(value: $settings.value.cropRight, in: 0...50, step: 1)
                                    }
                                }
                                
                                Button {
                                    Task {
                                        if !env.pipeline.isRunning {
                                            await env.startPipeline()
                                        } else {
                                            await env.restartPipeline()
                                        }
                                    }
                                } label: {
                                    Text("Apply Changes to LEDs")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.haloPrimary)
                                .padding(.top, Spacing.sm)
                            }
                            .disabled(settings.value.blackBarDetection)
                        }
                    }
                }
                .padding(.bottom, Spacing.lg)
                
                // Segment Configuration
                VStack(spacing: 0) {
                    layoutRow(title: "Bottom Left (Center to Corner)", bind: \.layout.bottomLeft)
                    Divider().padding(.leading, 16)
                    layoutRow(title: "Bottom Left Corner", bind: \.layout.bottomLeftCorner)
                    Divider().padding(.leading, 16)
                    layoutRow(title: "Left Edge", bind: \.layout.left)
                    Divider().padding(.leading, 16)
                    layoutRow(title: "Top Left Corner", bind: \.layout.topLeftCorner)
                    Divider().padding(.leading, 16)
                    layoutRow(title: "Top Edge", bind: \.layout.top)
                    Divider().padding(.leading, 16)
                    layoutRow(title: "Top Right Corner", bind: \.layout.topRightCorner)
                    Divider().padding(.leading, 16)
                    layoutRow(title: "Right Edge", bind: \.layout.right)
                    Divider().padding(.leading, 16)
                    layoutRow(title: "Bottom Right Corner", bind: \.layout.bottomRightCorner)
                    Divider().padding(.leading, 16)
                    layoutRow(title: "Bottom Right (Corner to Center)", bind: \.layout.bottomRight)
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                
                // Summary Footer
                HStack {
                    Text("Total LEDs Configured:")
                        .font(Typography.bodyMedium)
                    Spacer()
                    Text("\(settings.value.layout.totalLEDs)")
                        .font(Typography.headline)
                        .foregroundStyle(Color.haloPrimary)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }
            .padding(Spacing.xl)
        }
    }
    
    @ViewBuilder
    private func layoutRow(title: String, bind: WritableKeyPath<HaloSyncSettings, Int>) -> some View {
        HStack {
            Text(title)
                .font(Typography.body)
            
            Spacer()
            
            // Using a custom Binding to directly access/update the AppViewModel settings
            let binding = Binding<Int>(
                get: { self.settings.value[keyPath: bind] },
                set: { self.settings.value[keyPath: bind] = $0 }
            )
            
            TextField("", value: binding, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .multilineTextAlignment(.trailing)
            
            Stepper("", value: binding, in: 0...500)
                .labelsHidden()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }
}
