import Foundation

enum PrerecordedSpeechLanguage: String, CaseIterable, Identifiable {
    case chinese
    case english

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .chinese: "Chinese"
        case .english: "English"
        }
    }
}

enum PrerecordedSpeech: String, Codable, CaseIterable, Identifiable {
    case messageReminderMale = "bundled.message-reminder-male"
    case messageReminderFemale = "bundled.message-reminder-female"
    case checkYourMessagesMale = "bundled.check-your-messages-male"
    case checkYourMessagesFemale = "bundled.check-your-messages-female"

    var id: String { rawValue }

    var language: PrerecordedSpeechLanguage {
        switch self {
        case .messageReminderMale, .messageReminderFemale: .chinese
        case .checkYourMessagesMale, .checkYourMessagesFemale: .english
        }
    }

    var titleKey: String {
        switch self {
        case .messageReminderMale: "Message Reminder (Male)"
        case .messageReminderFemale: "Message Reminder (Female)"
        case .checkYourMessagesMale: "Check Your Messages (Male)"
        case .checkYourMessagesFemale: "Check Your Messages (Female)"
        }
    }

    var resourceName: String {
        switch self {
        case .messageReminderMale: "message-reminder-male"
        case .messageReminderFemale: "message-reminder-female"
        case .checkYourMessagesMale: "check-your-messages-man"
        case .checkYourMessagesFemale: "check-your-messages-female"
        }
    }

    nonisolated static func storedValue(_ value: String) -> Self? {
        switch value {
        case "bundled.text-me-back-soon-male": .checkYourMessagesMale
        case "bundled.text-me-back-soon-female": .checkYourMessagesFemale
        default: Self(rawValue: value)
        }
    }

    static func options(for language: PrerecordedSpeechLanguage) -> [Self] {
        allCases.filter { $0.language == language }
    }
}
