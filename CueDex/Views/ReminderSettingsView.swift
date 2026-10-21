import SwiftUI

struct ReminderSettingsView: View {
    let model: AppModel
    @State private var selectedPane = Pane.glow

    private enum Pane: Hashable { case glow, sound }

    var body: some View {
        @Bindable var preferences = model.preferences
        HStack(spacing: 0) {
            List(selection: Binding<AttentionSource?>(
                get: { preferences.selectedSource },
                set: { if let source = $0 { preferences.selectedSource = source } }
            )) {
                ForEach(AttentionSource.allCases) { source in
                    Text(verbatim: source.title).tag(source)
                }
            }
            .listStyle(.sidebar)
            .frame(width: 112)
            .accessibilityLabel(Text("Attention Source"))

            Divider()

            VStack(spacing: 0) {
                Picker("Cue Type", selection: $selectedPane) {
                    Text("Glow").tag(Pane.glow)
                    Text("Sound").tag(Pane.sound)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 200)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Group {
                    switch selectedPane {
                    case .glow:
                        GlowSettingsView(preferences: preferences, testGlow: model.testGlow, canPreview: !model.isPlayingCue)
                    case .sound:
                        SoundSettingsView(preferences: preferences, testSound: model.testSound, testSpeech: model.testSpeech, canPreview: !model.isPlayingCue)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(preferences.selectedSource)
                Text("Tests preview this source's effects only; they do not verify integration.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
    }
}
