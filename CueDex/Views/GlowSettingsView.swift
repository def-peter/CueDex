import SwiftUI

struct GlowSettingsView: View {
    @Bindable var preferences: PreferencesStore
    let testGlow: () -> Void

    var body: some View {
        Form {
            Section {
                Toggle("Screen-edge glow", isOn: $preferences.glowEnabled)
            }

            Section("Effect") {
                Picker("Effect", selection: $preferences.glowAnimation) {
                    ForEach(GlowAnimationStyle.allCases) { style in
                        Text(LocalizedStringKey(style.title)).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section("Appearance") {
                if preferences.glowAnimation == .alternatingFlash {
                    ColorPicker("Primary Color", selection: $preferences.flashPrimaryColor, supportsOpacity: false)
                    ColorPicker("Secondary Color", selection: $preferences.flashSecondaryColor, supportsOpacity: false)
                } else {
                    ColorPicker("Color", selection: $preferences.breathingGlowColor, supportsOpacity: false)
                }

                LabeledContent("Intensity") {
                    HStack(spacing: 10) {
                        Slider(value: $preferences.glowIntensity, in: 0.2...1)
                            .frame(width: 210)
                        Text(preferences.glowIntensity, format: .percent.precision(.fractionLength(0)))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 42, alignment: .trailing)
                    }
                }

                LabeledContent("Duration") {
                    HStack(spacing: 10) {
                        Slider(value: $preferences.glowDuration, in: 0.8...5, step: 0.2)
                            .frame(width: 210)
                        Text("\(preferences.glowDuration, specifier: "%.1f") s")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 42, alignment: .trailing)
                    }
                }
            }

            Section {
                Button("Test Glow", systemImage: "play.fill", action: testGlow)
                    .disabled(!preferences.glowEnabled)
            }
        }
        .formStyle(.grouped)
    }
}
