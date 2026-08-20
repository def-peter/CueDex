import Foundation
import Observation
import OSLog

enum CodexIntegrationStatus: Equatable {
    case notInstalled
    case installed
    case unavailable(String)

    var title: String {
        switch self {
        case .notInstalled: "Not enabled"
        case .installed: "Connected"
        case .unavailable: "Unavailable"
        }
    }
}

enum CodexIntegrationError: LocalizedError, Equatable {
    case invalidHooksFile

    var errorDescription: String? {
        switch self {
        case .invalidHooksFile:
            "CueDex could not update hooks.json because its structure is invalid."
        }
    }
}

@MainActor
@Observable
final class CodexIntegrationInstaller {
    private static let previousNotifierKey = "cuedex.previous-notifier"

    private let logger = Logger(subsystem: "com.peter.CueDex", category: "Integration")
    private let fileManager: FileManager
    private let defaults: UserDefaults
    let paths: CueDexPaths

    private(set) var status: CodexIntegrationStatus = .notInstalled
    private(set) var lastError: String?
    private(set) var requiresHookTrust = false

    init(paths: CueDexPaths, fileManager: FileManager = .default, defaults: UserDefaults = .standard) {
        self.paths = paths
        self.fileManager = fileManager
        self.defaults = defaults
        refresh()
    }

    var isInstalled: Bool { status == .installed }

    func refresh() {
        do {
            let helperPath = paths.helperURL.path(percentEncoded: false)
            let hasStopHook = try Self.containsStopHook(
                in: readHooksDataIfPresent(),
                helperPath: helperPath
            )
            let hasLegacyNotifier = Self.topLevelNotifyLine(in: try readConfigIfPresent())?
                .contains(helperPath) == true
            status = hasStopHook || hasLegacyNotifier ? .installed : .notInstalled
        } catch {
            status = .unavailable(error.localizedDescription)
        }
    }

    func install() {
        do {
            try writeHelper()
            let helperPath = paths.helperURL.path(percentEncoded: false)
            let originalHooks = try readHooksDataIfPresent()
            let hadStopHook = try Self.containsStopHook(in: originalHooks, helperPath: helperPath)
            let hadLegacyNotifier = Self.topLevelNotifyLine(in: try readConfigIfPresent())?
                .contains(helperPath) == true
            if !hadStopHook {
                let updatedHooks = try Self.addingStopHook(to: originalHooks, helperPath: helperPath)
                try writeHooksData(updatedHooks, backingUp: originalHooks)
            }
            try migrateLegacyNotifierIfNeeded()
            status = .installed
            lastError = nil
            requiresHookTrust = requiresHookTrust || !hadStopHook || hadLegacyNotifier
            logger.info("Installed Codex main-agent Stop hook")
        } catch {
            lastError = error.localizedDescription
            refresh()
            logger.error("Hook installation failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func uninstall() {
        do {
            let helperPath = paths.helperURL.path(percentEncoded: false)
            let originalHooks = try readHooksDataIfPresent()
            if try Self.containsStopHook(in: originalHooks, helperPath: helperPath) {
                let updatedHooks = try Self.removingStopHook(from: originalHooks, helperPath: helperPath)
                try writeHooksData(updatedHooks, backingUp: originalHooks)
            }
            try migrateLegacyNotifierIfNeeded()
            status = .notInstalled
            lastError = nil
            requiresHookTrust = false
            logger.info("Removed Codex main-agent Stop hook")
        } catch {
            lastError = error.localizedDescription
            refresh()
        }
    }

    func refreshHelperIfInstalled() {
        guard isInstalled else { return }
        install()
    }

    nonisolated static func removingManagedNotifier(
        from content: String,
        helperPath: String,
        restoring previousNotifier: String?
    ) -> String {
        var lines = content.components(separatedBy: "\n")
        let tableIndex = lines.firstIndex { $0.trimmingCharacters(in: .whitespaces).hasPrefix("[") } ?? lines.count

        guard let index = lines[..<tableIndex].firstIndex(where: {
            isNotifyLine($0) && $0.contains(helperPath)
        }) else {
            return content
        }

        if let previousNotifier {
            lines[index] = previousNotifier
        } else {
            lines.remove(at: index)
            if index < lines.count, lines[index].isEmpty, index > 0, lines[index - 1].isEmpty {
                lines.remove(at: index)
            }
        }
        return joined(lines)
    }

    nonisolated static func topLevelNotifyLine(in content: String) -> String? {
        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") { return nil }
            if isNotifyLine(line) { return line }
        }
        return nil
    }

    nonisolated static func containsStopHook(in data: Data?, helperPath: String) throws -> Bool {
        let root = try hooksRoot(from: data)
        return try stopHookGroups(in: root).contains { group in
            try hookHandlers(in: group).contains { handler in
                guard let command = handler["command"] as? String else { return false }
                return isManagedHookCommand(command, helperPath: helperPath)
            }
        }
    }

    nonisolated static func addingStopHook(to data: Data?, helperPath: String) throws -> Data {
        var root = try hooksRoot(from: data)
        var hooks = try hooksTable(in: root)
        var groups = try stopHookGroups(in: root)

        if try containsStopHook(in: data, helperPath: helperPath), let data {
            return data
        }

        let handler: [String: Any] = [
            "command": shellQuoted(helperPath),
            "timeout": 3,
            "type": "command"
        ]
        groups.append(["hooks": [handler]])
        hooks["Stop"] = groups
        root["hooks"] = hooks
        return try serializedHooks(root)
    }

    nonisolated static func removingStopHook(from data: Data?, helperPath: String) throws -> Data? {
        var root = try hooksRoot(from: data)
        var hooks = try hooksTable(in: root)
        let groups = try stopHookGroups(in: root)
        var remainingGroups: [[String: Any]] = []

        for var group in groups {
            let remainingHandlers = try hookHandlers(in: group).filter { handler in
                guard let command = handler["command"] as? String else { return true }
                return !isManagedHookCommand(command, helperPath: helperPath)
            }
            if !remainingHandlers.isEmpty {
                group["hooks"] = remainingHandlers
                remainingGroups.append(group)
            }
        }

        if remainingGroups.isEmpty {
            hooks.removeValue(forKey: "Stop")
        } else {
            hooks["Stop"] = remainingGroups
        }

        if hooks.isEmpty {
            root.removeValue(forKey: "hooks")
        } else {
            root["hooks"] = hooks
        }
        return root.isEmpty ? nil : try serializedHooks(root)
    }

    private func readConfigIfPresent() throws -> String {
        guard fileManager.fileExists(atPath: paths.codexConfigURL.path) else { return "" }
        return try String(contentsOf: paths.codexConfigURL, encoding: .utf8)
    }

    private func writeConfig(_ content: String, backingUp original: String, createBackup: Bool) throws {
        try fileManager.createDirectory(at: paths.codexHome, withIntermediateDirectories: true)
        if createBackup, fileManager.fileExists(atPath: paths.codexConfigURL.path) {
            let backupURL = paths.codexHome.appending(path: "config.toml.cuedex-backup")
            if !fileManager.fileExists(atPath: backupURL.path) {
                try original.write(to: backupURL, atomically: true, encoding: .utf8)
            }
        }
        try content.write(to: paths.codexConfigURL, atomically: true, encoding: .utf8)
    }

    private func readHooksDataIfPresent() throws -> Data? {
        guard fileManager.fileExists(atPath: paths.codexHooksURL.path) else { return nil }
        return try Data(contentsOf: paths.codexHooksURL)
    }

    private func writeHooksData(_ data: Data?, backingUp original: Data?) throws {
        try fileManager.createDirectory(at: paths.codexHome, withIntermediateDirectories: true)
        if let original {
            let backupURL = paths.codexHome.appending(path: "hooks.json.cuedex-backup")
            if !fileManager.fileExists(atPath: backupURL.path) {
                try original.write(to: backupURL, options: .atomic)
            }
        }

        if let data {
            try data.write(to: paths.codexHooksURL, options: .atomic)
        } else if fileManager.fileExists(atPath: paths.codexHooksURL.path) {
            try fileManager.removeItem(at: paths.codexHooksURL)
        }
    }

    private func migrateLegacyNotifierIfNeeded() throws {
        let original = try readConfigIfPresent()
        let helperPath = paths.helperURL.path(percentEncoded: false)
        guard Self.topLevelNotifyLine(in: original)?.contains(helperPath) == true else { return }

        let updated = Self.removingManagedNotifier(
            from: original,
            helperPath: helperPath,
            restoring: defaults.string(forKey: Self.previousNotifierKey)
        )
        try writeConfig(updated, backingUp: original, createBackup: true)
        defaults.removeObject(forKey: Self.previousNotifierKey)
    }

    private func writeHelper() throws {
        try fileManager.createDirectory(at: paths.helperDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: paths.eventsDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: paths.diagnosticsDirectory, withIntermediateDirectories: true)

        let eventDirectory = Self.shellQuoted(paths.eventsDirectory.path(percentEncoded: false))
        let diagnosticsDirectory = Self.shellQuoted(paths.diagnosticsDirectory.path(percentEncoded: false))
        let appBundle = Self.shellQuoted(paths.appBundle.path(percentEncoded: false))
        let script = """
        #!/bin/sh
        set -eu
        PAYLOAD=$(/bin/cat)
        EVENT_DIR=\(eventDirectory)
        DIAGNOSTICS_DIR=\(diagnosticsDirectory)
        /bin/mkdir -p "$EVENT_DIR"
        /bin/mkdir -p "$DIAGNOSTICS_DIR"

        extract_field() {
            printf '%s' "$PAYLOAD" | /usr/bin/plutil -extract "$1" raw -o - - 2>/dev/null || true
        }

        add_string_field() {
            [ -n "$2" ] || return 0
            [ "$2" != "null" ] || return 0
            /usr/bin/plutil -insert "$1" -string "$2" "$DIAGNOSTIC_PLIST" >/dev/null
        }

        write_diagnostic() {
            TIMESTAMP=$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')
            FILE_TIMESTAMP=$(/bin/date -u '+%Y%m%dT%H%M%SZ')
            DIAGNOSTIC_PLIST="$DIAGNOSTICS_DIR/.hook-$FILE_TIMESTAMP-$$.plist"
            DIAGNOSTIC_TEMP="$DIAGNOSTICS_DIR/.hook-$FILE_TIMESTAMP-$$.json"
            DIAGNOSTIC_FILE="$DIAGNOSTICS_DIR/hook-$FILE_TIMESTAMP-$$.json"
            /usr/bin/plutil -create xml1 "$DIAGNOSTIC_PLIST"
            /bin/chmod 600 "$DIAGNOSTIC_PLIST"
            /usr/bin/plutil -insert timestamp -string "$TIMESTAMP" "$DIAGNOSTIC_PLIST" >/dev/null
            /usr/bin/plutil -insert helper_pid -integer "$$" "$DIAGNOSTIC_PLIST" >/dev/null
            /usr/bin/plutil -insert parent_pid -integer "$PPID" "$DIAGNOSTIC_PLIST" >/dev/null
            /usr/bin/plutil -insert decision -string "$DECISION" "$DIAGNOSTIC_PLIST" >/dev/null
            /usr/bin/plutil -insert payload_bytes -integer "$PAYLOAD_BYTES" "$DIAGNOSTIC_PLIST" >/dev/null
            /usr/bin/plutil -insert assistant_message_bytes -integer "$MESSAGE_BYTES" "$DIAGNOSTIC_PLIST" >/dev/null
            add_string_field hook_event_name "$HOOK_EVENT"
            add_string_field turn_id "$TURN_ID"
            add_string_field session_id "$SESSION_ID"
            add_string_field cwd "$HOOK_CWD"
            add_string_field transcript_path "$TRANSCRIPT_PATH"
            add_string_field model "$MODEL"
            add_string_field permission_mode "$PERMISSION_MODE"
            add_string_field stop_hook_active "$STOP_HOOK_ACTIVE"
            add_string_field assistant_message_sha256 "$MESSAGE_SHA256"
            /usr/bin/plutil -convert json -o "$DIAGNOSTIC_TEMP" "$DIAGNOSTIC_PLIST"
            /bin/chmod 600 "$DIAGNOSTIC_TEMP"
            /bin/mv -f "$DIAGNOSTIC_TEMP" "$DIAGNOSTIC_FILE"
            /bin/rm -f "$DIAGNOSTIC_PLIST"
            /usr/bin/find "$DIAGNOSTICS_DIR" -type f -name 'hook-*.json' -mtime +7 -delete 2>/dev/null || true
        }

        HOOK_EVENT=$(extract_field hook_event_name)
        TURN_ID=$(extract_field turn_id)
        SESSION_ID=$(extract_field session_id)
        HOOK_CWD=$(extract_field cwd)
        TRANSCRIPT_PATH=$(extract_field transcript_path)
        MODEL=$(extract_field model)
        PERMISSION_MODE=$(extract_field permission_mode)
        STOP_HOOK_ACTIVE=$(extract_field stop_hook_active)
        LAST_ASSISTANT_MESSAGE=$(extract_field last_assistant_message)
        PAYLOAD_BYTES=$(printf '%s' "$PAYLOAD" | /usr/bin/wc -c | /usr/bin/tr -d '[:space:]')
        MESSAGE_BYTES=$(printf '%s' "$LAST_ASSISTANT_MESSAGE" | /usr/bin/wc -c | /usr/bin/tr -d '[:space:]')
        MESSAGE_SHA256=""
        if [ -n "$LAST_ASSISTANT_MESSAGE" ] && [ "$LAST_ASSISTANT_MESSAGE" != "null" ]; then
            MESSAGE_SHA256=$(printf '%s' "$LAST_ASSISTANT_MESSAGE" | /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}')
        fi

        if [ "$HOOK_EVENT" != "Stop" ]; then
            DECISION="ignored_non_stop"
            write_diagnostic || true
            exit 0
        fi
        if [ -z "$LAST_ASSISTANT_MESSAGE" ] || [ "$LAST_ASSISTANT_MESSAGE" = "null" ]; then
            DECISION="ignored_missing_message"
            write_diagnostic || true
            exit 0
        fi
        MESSAGE_TEXT=$(printf '%s' "$LAST_ASSISTANT_MESSAGE" | /usr/bin/tr -d '[:space:]')
        if [ -z "$MESSAGE_TEXT" ]; then
            DECISION="ignored_blank_message"
            write_diagnostic || true
            exit 0
        fi
        if [ -z "$TRANSCRIPT_PATH" ] || [ "$TRANSCRIPT_PATH" = "null" ]; then
            DECISION="ignored_ephemeral_session"
            write_diagnostic || true
            exit 0
        fi
        if [ -n "$TURN_ID" ] && [ "$TURN_ID" != "null" ]; then
            LAST_TURN_FILE="$EVENT_DIR/.last-turn-id"
            PREVIOUS_TURN=$(/bin/cat "$LAST_TURN_FILE" 2>/dev/null || true)
            if [ "$PREVIOUS_TURN" = "$TURN_ID" ]; then
                DECISION="ignored_duplicate_turn"
                write_diagnostic || true
                exit 0
            fi
            TEMP_LAST_TURN="$LAST_TURN_FILE.$$"
            printf '%s' "$TURN_ID" > "$TEMP_LAST_TURN"
            /bin/mv -f "$TEMP_LAST_TURN" "$LAST_TURN_FILE"
        fi
        /usr/bin/touch "$EVENT_DIR/turn-complete.$$"
        DECISION="notified"
        write_diagnostic || true
        /usr/bin/open -gj \(appBundle) >/dev/null 2>&1 || true
        exit 0
        """

        try script.write(to: paths.helperURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: paths.helperURL.path)
    }

    nonisolated private static func hooksRoot(from data: Data?) throws -> [String: Any] {
        guard let data else { return [:] }
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let root = object as? [String: Any] else {
            throw CodexIntegrationError.invalidHooksFile
        }
        return root
    }

    nonisolated private static func hooksTable(in root: [String: Any]) throws -> [String: Any] {
        guard let rawHooks = root["hooks"] else { return [:] }
        guard let hooks = rawHooks as? [String: Any] else {
            throw CodexIntegrationError.invalidHooksFile
        }
        return hooks
    }

    nonisolated private static func stopHookGroups(in root: [String: Any]) throws -> [[String: Any]] {
        let hooks = try hooksTable(in: root)
        guard let rawGroups = hooks["Stop"] else { return [] }
        guard let groups = rawGroups as? [[String: Any]] else {
            throw CodexIntegrationError.invalidHooksFile
        }
        for group in groups {
            _ = try hookHandlers(in: group)
        }
        return groups
    }

    nonisolated private static func hookHandlers(in group: [String: Any]) throws -> [[String: Any]] {
        guard let handlers = group["hooks"] as? [[String: Any]] else {
            throw CodexIntegrationError.invalidHooksFile
        }
        return handlers
    }

    nonisolated private static func serializedHooks(_ root: [String: Any]) throws -> Data {
        guard JSONSerialization.isValidJSONObject(root) else {
            throw CodexIntegrationError.invalidHooksFile
        }
        var data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0A)
        return data
    }

    nonisolated private static func isManagedHookCommand(_ command: String, helperPath: String) -> Bool {
        command == helperPath || command == shellQuoted(helperPath)
    }

    nonisolated private static func isNotifyLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("notify") else { return false }
        let remainder = trimmed.dropFirst("notify".count).drop(while: { $0.isWhitespace })
        return remainder.first == "="
    }

    nonisolated private static func joined(_ lines: [String]) -> String {
        lines.joined(separator: "\n")
    }

    nonisolated private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
