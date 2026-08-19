import AVFoundation
import Foundation

struct SpeechVoiceOption: Identifiable, Equatable {
    let id: String
    let name: String
    let language: String

    var displayName: String {
        "\(name) (\(language))"
    }

    func matchScore(for query: String) -> Int? {
        let needle = Self.normalized(query)
        guard !needle.isEmpty else { return 0 }

        let normalizedName = Self.normalized(name)
        let normalizedDisplayName = Self.normalized(displayName)
        if normalizedName == needle { return 0 }
        if normalizedName.hasPrefix(needle) { return 1 }
        if normalizedName.contains(needle) { return 2 }
        if normalizedDisplayName.contains(needle) { return 3 }

        let compactNeedle = needle.filter { $0.isLetter || $0.isNumber }
        let compactDisplayName = normalizedDisplayName.filter { $0.isLetter || $0.isNumber }
        guard !compactNeedle.isEmpty else { return nil }

        var searchIndex = compactDisplayName.startIndex
        var gapScore = 0
        for character in compactNeedle {
            guard let matchIndex = compactDisplayName[searchIndex...].firstIndex(of: character) else {
                return nil
            }
            gapScore += compactDisplayName.distance(from: searchIndex, to: matchIndex)
            searchIndex = compactDisplayName.index(after: matchIndex)
        }
        return 10 + gapScore
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum SpeechVoiceCatalog {
    static let voices: [SpeechVoiceOption] = AVSpeechSynthesisVoice.speechVoices()
        .map { voice in
            SpeechVoiceOption(
                id: voice.identifier,
                name: voice.name,
                language: voice.language
            )
        }
        .sorted { lhs, rhs in
            lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }

    static func voice(withIdentifier identifier: String?) -> SpeechVoiceOption? {
        guard let identifier else { return nil }
        return voices.first { $0.id == identifier }
    }

    static func voices(matching query: String) -> [SpeechVoiceOption] {
        voices
            .compactMap { voice in
                voice.matchScore(for: query).map { (voice, $0) }
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                return lhs.0.displayName.localizedStandardCompare(rhs.0.displayName) == .orderedAscending
            }
            .map(\.0)
    }
}
