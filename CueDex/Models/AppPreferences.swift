import Foundation

struct GlobalPreferences: Codable, Equatable {
    var appLanguage = AppLanguage.simplifiedChinese
    var isPaused = false
    var quietHoursEnabled = false
    var quietHoursStartMinutes = 22 * 60
    var quietHoursEndMinutes = 8 * 60

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        appLanguage = try values.decodeIfPresent(AppLanguage.self, forKey: .appLanguage) ?? .simplifiedChinese
        isPaused = try values.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
        quietHoursEnabled = try values.decodeIfPresent(Bool.self, forKey: .quietHoursEnabled) ?? false
        quietHoursStartMinutes = min(max(try values.decodeIfPresent(Int.self, forKey: .quietHoursStartMinutes) ?? 22 * 60, 0), 1439)
        quietHoursEndMinutes = min(max(try values.decodeIfPresent(Int.self, forKey: .quietHoursEndMinutes) ?? 8 * 60, 0), 1439)
    }

    func isQuiet(at date: Date, calendar: Calendar = .current) -> Bool {
        guard quietHoursEnabled else { return false }
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if quietHoursStartMinutes == quietHoursEndMinutes { return true }
        if quietHoursStartMinutes < quietHoursEndMinutes {
            return quietHoursStartMinutes <= minute && minute < quietHoursEndMinutes
        }
        return minute >= quietHoursStartMinutes || minute < quietHoursEndMinutes
    }
}

struct AppPreferences: Codable, Equatable {
    var global: GlobalPreferences
    var codex: CuePreferences
    var opencode: CuePreferences

    init(legacyData: Data? = nil) {
        global = legacyData.flatMap { try? JSONDecoder().decode(GlobalPreferences.self, from: $0) } ?? GlobalPreferences()
        codex = legacyData.flatMap { try? JSONDecoder().decode(CuePreferences.self, from: $0) }
            ?? .defaults(for: .codex, language: global.appLanguage)
        opencode = .defaults(for: .opencode, language: global.appLanguage)
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        global = try values.decodeIfPresent(GlobalPreferences.self, forKey: .global) ?? GlobalPreferences()
        codex = try values.contains(.codex)
            ? CuePreferences(from: values.superDecoder(forKey: .codex), defaultSpeechText: global.appLanguage.defaultSpeechText(for: .codex))
            : .defaults(for: .codex, language: global.appLanguage)
        opencode = try values.contains(.opencode)
            ? CuePreferences(from: values.superDecoder(forKey: .opencode), defaultSpeechText: global.appLanguage.defaultSpeechText(for: .opencode))
            : .defaults(for: .opencode, language: global.appLanguage)
    }

    subscript(source: AttentionSource) -> CuePreferences {
        get { source == .codex ? codex : opencode }
        set {
            switch source {
            case .codex: codex = newValue
            case .opencode: opencode = newValue
            }
        }
    }
}
