import SwiftUI

struct SpeechVoicePicker: View {
    @Binding var selection: String?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search voices", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit(selectFirstMatch)
            }
            .padding(10)

            Divider()

            if matchingVoices.isEmpty {
                ContentUnavailableView("No matching voices", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        voiceRow(
                            id: nil,
                            name: String(localized: "System Default"),
                            language: nil
                        )
                    }

                    ForEach(matchingVoices) { voice in
                        voiceRow(id: voice.id, name: voice.name, language: voice.language)
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 360, height: 400)
        .onAppear { isSearchFocused = true }
    }

    @ViewBuilder
    private func voiceRow(id: String?, name: String, language: String?) -> some View {
        Button {
            selection = id
            dismiss()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .foregroundStyle(.primary)
                    if let language {
                        Text(language)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 12)
                if selection == id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var matchingVoices: [SpeechVoiceOption] {
        SpeechVoiceCatalog.voices(matching: searchText)
    }

    private func selectFirstMatch() {
        guard let firstMatch = matchingVoices.first else { return }
        selection = firstMatch.id
        dismiss()
    }
}
