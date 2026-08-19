import Foundation

enum AppVersion {
    static func normalized(_ value: String) -> String {
        var result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.lowercased().hasPrefix("v") {
            result.removeFirst()
        }
        return result
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let candidate = normalized(candidate)
        let current = normalized(current)

        guard !candidate.isEmpty, !current.isEmpty else { return false }
        return candidate.compare(current, options: [.numeric, .caseInsensitive]) == .orderedDescending
    }
}
