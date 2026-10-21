import Foundation

enum AttentionSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case codex
    case opencode

    var id: Self { self }
    var title: String { self == .codex ? "Codex" : "OpenCode" }
}
