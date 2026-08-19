import Foundation

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: Self { self }
    var locale: Locale { Locale(identifier: rawValue) }

    var nativeName: String {
        switch self {
        case .simplifiedChinese: "简体中文"
        case .english: "English"
        }
    }

    var defaultSpeechText: String {
        switch self {
        case .simplifiedChinese: "Codex 已回复完成。"
        case .english: "Codex has finished responding."
        }
    }
}
