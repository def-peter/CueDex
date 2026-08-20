import Foundation

enum SpeechMode: String, Codable, CaseIterable, Identifiable {
    case prerecorded
    case system

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .prerecorded: "Pre-recorded"
        case .system: "System Speech"
        }
    }
}
