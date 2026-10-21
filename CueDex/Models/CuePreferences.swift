import Foundation

enum GlowAnimationStyle: String, Codable, CaseIterable, Identifiable {
    case breathing
    case alternatingFlash

    var id: Self { self }

    var title: String {
        switch self {
        case .breathing: "Monochrome Breathing"
        case .alternatingFlash: "Two-Color Flash"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        switch try container.decode(String.self) {
        case Self.alternatingFlash.rawValue, "marquee":
            self = .alternatingFlash
        case Self.breathing.rawValue, "softFlash":
            self = .breathing
        default:
            // Unknown future values keep the rest of the saved preferences usable.
            self = .breathing
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct CuePreferences: Codable, Equatable {
    var glowEnabled = true
    var soundEnabled = true
    var speechEnabled = false
    var glowRed = 0.24
    var glowGreen = 0.58
    var glowBlue = 1.0
    var glowFlashPrimaryRed = 1.0
    var glowFlashPrimaryGreen = 0.08
    var glowFlashPrimaryBlue = 0.12
    var glowSecondaryRed = 0.15
    var glowSecondaryGreen = 0.48
    var glowSecondaryBlue = 1.0
    var glowAnimation = GlowAnimationStyle.breathing
    var soundIdentifier = "Glass"
    var customSoundPath: String?
    var customSoundName: String?
    var speechMode = SpeechMode.system
    var prerecordedSpeech = PrerecordedSpeech.messageReminderMale
    var speechVoiceIdentifier: String?
    var speechText = AppLanguage.simplifiedChinese.defaultSpeechText

    static let defaults = CuePreferences()

    init() {}

    static func defaults(for source: AttentionSource, language: AppLanguage) -> Self {
        var result = Self()
        result.speechText = language.defaultSpeechText(for: source)
        return result
    }

    init(from decoder: Decoder) throws {
        try self.init(from: decoder, defaultSpeechText: AppLanguage.simplifiedChinese.defaultSpeechText, isLegacy: true)
    }

    init(from decoder: Decoder, defaultSpeechText: String, isLegacy: Bool = false) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var defaults = Self()
        defaults.speechText = defaultSpeechText

        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        let storedLanguage = try legacy.decodeIfPresent(AppLanguage.self, forKey: .appLanguage)
        if let storedLanguage { defaults.speechText = storedLanguage.defaultSpeechText }
        glowEnabled = try container.decodeIfPresent(Bool.self, forKey: .glowEnabled) ?? defaults.glowEnabled
        let storedSoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? defaults.soundEnabled
        let storedSpeechEnabled = try container.decodeIfPresent(Bool.self, forKey: .speechEnabled) ?? defaults.speechEnabled
        soundEnabled = storedSoundEnabled
        speechEnabled = storedSpeechEnabled
        let storedGlowRed = try container.decodeIfPresent(Double.self, forKey: .glowRed)
        let storedGlowGreen = try container.decodeIfPresent(Double.self, forKey: .glowGreen)
        let storedGlowBlue = try container.decodeIfPresent(Double.self, forKey: .glowBlue)
        glowRed = storedGlowRed ?? defaults.glowRed
        glowGreen = storedGlowGreen ?? defaults.glowGreen
        glowBlue = storedGlowBlue ?? defaults.glowBlue
        glowFlashPrimaryRed = try container.decodeIfPresent(Double.self, forKey: .glowFlashPrimaryRed)
            ?? storedGlowRed
            ?? defaults.glowFlashPrimaryRed
        glowFlashPrimaryGreen = try container.decodeIfPresent(Double.self, forKey: .glowFlashPrimaryGreen)
            ?? storedGlowGreen
            ?? defaults.glowFlashPrimaryGreen
        glowFlashPrimaryBlue = try container.decodeIfPresent(Double.self, forKey: .glowFlashPrimaryBlue)
            ?? storedGlowBlue
            ?? defaults.glowFlashPrimaryBlue
        glowSecondaryRed = try container.decodeIfPresent(Double.self, forKey: .glowSecondaryRed) ?? defaults.glowSecondaryRed
        glowSecondaryGreen = try container.decodeIfPresent(Double.self, forKey: .glowSecondaryGreen) ?? defaults.glowSecondaryGreen
        glowSecondaryBlue = try container.decodeIfPresent(Double.self, forKey: .glowSecondaryBlue) ?? defaults.glowSecondaryBlue
        glowAnimation = try container.decodeIfPresent(GlowAnimationStyle.self, forKey: .glowAnimation) ?? defaults.glowAnimation
        soundIdentifier = try container.decodeIfPresent(String.self, forKey: .soundIdentifier) ?? defaults.soundIdentifier
        customSoundPath = try container.decodeIfPresent(String.self, forKey: .customSoundPath)
        customSoundName = try container.decodeIfPresent(String.self, forKey: .customSoundName)
            ?? customSoundPath.map { URL(filePath: $0).deletingPathExtension().lastPathComponent }
        let storedSpeechMode = try container.decodeIfPresent(String.self, forKey: .speechMode)
            .flatMap(SpeechMode.init(rawValue:))
        speechMode = storedSpeechMode ?? defaults.speechMode
        let storedPrerecordedSpeech = try container.decodeIfPresent(String.self, forKey: .prerecordedSpeech)
            .flatMap(PrerecordedSpeech.storedValue)
        prerecordedSpeech = storedPrerecordedSpeech ?? defaults.prerecordedSpeech

        if storedSpeechMode == nil,
           let legacyRecording = PrerecordedSpeech.storedValue(soundIdentifier) {
            prerecordedSpeech = legacyRecording
            soundIdentifier = defaults.soundIdentifier
            soundEnabled = false

            if storedSpeechEnabled && !storedSoundEnabled {
                speechMode = .system
                speechEnabled = true
            } else {
                speechMode = .prerecorded
                speechEnabled = storedSoundEnabled
            }
        }

        speechVoiceIdentifier = try container.decodeIfPresent(String.self, forKey: .speechVoiceIdentifier)
        let storedSpeechText = try container.decodeIfPresent(String.self, forKey: .speechText)
        if isLegacy, storedLanguage == nil, storedSpeechText == AppLanguage.english.defaultSpeechText {
            speechText = defaults.speechText
        } else {
            speechText = storedSpeechText ?? defaults.speechText
        }
    }

    private enum LegacyKeys: String, CodingKey {
        case appLanguage
    }
}
