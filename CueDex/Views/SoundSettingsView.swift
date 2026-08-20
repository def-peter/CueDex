import SwiftUI

struct SoundSettingsView: View {
    @Bindable var preferences: PreferencesStore
    let testSound: () -> Void
    let testSpeech: () -> Void
    @State private var isVoicePickerPresented = false
    @State private var customSoundImportError: String?

    var body: some View {
        Form {
            Section("Notification Sound") {
                Toggle("Play notification sound", isOn: $preferences.soundEnabled)

                Picker("Sound", selection: $preferences.soundIdentifier) {
                    ForEach(SoundController.systemSounds, id: \.self) { sound in
                        Text(sound).tag(sound)
                    }
                    if preferences.customSoundPath != nil {
                        Divider()
                        Text(customSoundName).tag("custom")
                    }
                }
                .disabled(!preferences.soundEnabled)

                LabeledContent("Volume") {
                    HStack(spacing: 10) {
                        Image(systemName: "speaker.wave.1")
                            .foregroundStyle(.secondary)
                        Slider(value: $preferences.soundVolume, in: 0...1)
                            .frame(width: 210)
                        Image(systemName: "speaker.wave.3")
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!preferences.soundEnabled)

                HStack {
                    Button("Choose Audio File", systemImage: "folder") {
                        guard let url = AudioFilePicker.choose() else { return }
                        do {
                            try preferences.setCustomSound(url)
                            customSoundImportError = nil
                        } catch {
                            customSoundImportError = String(localized: "Unable to import audio file.")
                        }
                    }

                    if preferences.customSoundPath != nil {
                        Button(role: .destructive) {
                            preferences.removeCustomSound()
                            customSoundImportError = nil
                        } label: {
                            Label("Remove Custom Sound", systemImage: "trash")
                        }
                    }
                }
                .disabled(!preferences.soundEnabled)

                if let customSoundImportError {
                    Text(verbatim: customSoundImportError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button("Test Sound", systemImage: "play.fill", action: testSound)
                    .disabled(!preferences.soundEnabled)
            }

            Section("Speech") {
                Toggle("Voice notification", isOn: $preferences.speechEnabled)

                Picker("Mode", selection: $preferences.speechMode) {
                    ForEach(SpeechMode.allCases) { mode in
                        Text(LocalizedStringKey(mode.titleKey)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!preferences.speechEnabled)

                if preferences.speechMode == .prerecorded {
                    Picker("Recording", selection: $preferences.prerecordedSpeech) {
                        ForEach(PrerecordedSpeechLanguage.allCases) { language in
                            Section(LocalizedStringKey(language.titleKey)) {
                                ForEach(PrerecordedSpeech.options(for: language)) { recording in
                                    Text(LocalizedStringKey(recording.titleKey)).tag(recording)
                                }
                            }
                        }
                    }
                    .disabled(!preferences.speechEnabled)
                } else {
                    LabeledContent("Voice") {
                        Button {
                            isVoicePickerPresented = true
                        } label: {
                            HStack(spacing: 6) {
                                Text(selectedVoiceName)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 250, alignment: .trailing)
                        }
                        .popover(isPresented: $isVoicePickerPresented) {
                            SpeechVoicePicker(selection: $preferences.speechVoiceIdentifier)
                        }
                    }
                    .disabled(!preferences.speechEnabled)

                    LabeledContent("Message") {
                        TextField(text: $preferences.speechText, prompt: nil) {
                            EmptyView()
                        }
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 300)
                        .accessibilityLabel(Text("Message"))
                    }
                    .disabled(!preferences.speechEnabled)
                }

                LabeledContent("Volume") {
                    HStack(spacing: 10) {
                        Image(systemName: "speaker.wave.1")
                            .foregroundStyle(.secondary)
                        Slider(value: $preferences.speechVolume, in: 0...1)
                            .frame(width: 210)
                        Image(systemName: "speaker.wave.3")
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!preferences.speechEnabled)

                Button("Test Speech", systemImage: "waveform", action: testSpeech)
                    .disabled(!canTestSpeech)
            }
        }
        .formStyle(.grouped)
    }

    private var canTestSpeech: Bool {
        guard preferences.speechEnabled else { return false }
        switch preferences.speechMode {
        case .prerecorded:
            return true
        case .system:
            return !preferences.speechText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var selectedVoiceName: String {
        SpeechVoiceCatalog.voice(withIdentifier: preferences.speechVoiceIdentifier)?.displayName
            ?? String(localized: "System Default")
    }

    private var customSoundName: String {
        preferences.customSoundName ?? String(localized: "Custom")
    }
}
