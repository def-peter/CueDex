import Foundation
import Observation

@MainActor
@Observable
final class OpenCodeIntegrationInstaller {
    nonisolated static func supportsVersion(_ version: String?) -> Bool {
        guard let version,
              version.range(
                of: #"\Av?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?\z"#,
                options: .regularExpression
              ) != nil else { return false }
        let core = version.drop(while: { $0 == "v" }).split(separator: "+")[0]
        let parts = core.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 3, parts.allSatisfy({ $0 <= 9_007_199_254_740_991 }) else { return false }
        return parts[0] == 2 && (parts[1] > 1 || (parts[1] == 1 && parts[2] >= 1))
    }
    private static let ownership = "// CueDex managed OpenCode V2 bridge."
    let paths: CueDexPaths
    private let fileManager: FileManager
    private let versionProvider: @Sendable () async -> String?
    private let pluginTemplate: () throws -> String
    private(set) var isInstalled = false
    private(set) var isCheckingVersion = false
    private(set) var detectedVersion: String?
    private(set) var compatibilityNotice: String?
    private(set) var lastError: String?

    init(
        paths: CueDexPaths,
        fileManager: FileManager = .default,
        versionProvider: @escaping @Sendable () async -> String? = { await OpenCodeIntegrationInstaller.detectVersion() },
        pluginTemplate: @escaping () throws -> String = {
            guard let resource = Bundle.main.url(forResource: "cuedex-opencode", withExtension: "js") else {
                throw CocoaError(.fileNoSuchFile)
            }
            return try String(contentsOf: resource, encoding: .utf8)
        }
    ) {
        self.paths = paths
        self.fileManager = fileManager
        self.versionProvider = versionProvider
        self.pluginTemplate = pluginTemplate
        refresh()
    }

    func refresh() {
        let content = try? String(contentsOf: paths.opencodePluginURL, encoding: .utf8)
        isInstalled = content?.hasPrefix(Self.ownership) == true
            && fileManager.fileExists(atPath: paths.opencodeGateURL.path)
    }

    func checkVersion() async {
        guard !isCheckingVersion else { return }
        isCheckingVersion = true
        detectedVersion = await versionProvider()
        compatibilityNotice = nil
        isCheckingVersion = false
    }

    func install() async {
        await checkVersion()
        lastError = nil
        guard Self.supportsVersion(detectedVersion) else {
            compatibilityNotice = detectedVersion == nil
                ? "OpenCode CLI was not detected, so installation was not performed."
                : "The detected OpenCode version is outside the supported range. CueDex supports stable OpenCode 2.x (>= 2.1.1, < 3.0.0), so installation was not performed."
            return
        }
        do {
            if fileManager.fileExists(atPath: paths.opencodePluginURL.path) {
                let existing = try String(contentsOf: paths.opencodePluginURL, encoding: .utf8)
                guard existing.hasPrefix(Self.ownership) else { throw InstallerError.foreignFile }
            }
            let generation = UUID().uuidString
            let template = try pluginTemplate()
            let script = try Self.render(template, paths: paths, generation: generation)
            try fileManager.createDirectory(at: paths.opencodePluginURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.createDirectory(at: paths.applicationSupport, withIntermediateDirectories: true)
            try script.write(to: paths.opencodePluginURL, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: paths.opencodePluginURL.path)
            try generation.write(to: paths.opencodeGateURL, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: paths.opencodeGateURL.path)
            lastError = nil
        } catch {
            lastError = "Unable to install the CueDex OpenCode plugin. Existing unowned files are never replaced."
        }
        refresh()
    }

    func uninstall() {
        compatibilityNotice = nil
        do {
            // Invalidate still-loaded instances before removing the discovered file.
            if fileManager.fileExists(atPath: paths.opencodeGateURL.path) {
                try fileManager.removeItem(at: paths.opencodeGateURL)
            }
            if fileManager.fileExists(atPath: paths.opencodePluginURL.path) {
                let content = try String(contentsOf: paths.opencodePluginURL, encoding: .utf8)
                guard content.hasPrefix(Self.ownership) else { throw InstallerError.foreignFile }
                try fileManager.removeItem(at: paths.opencodePluginURL)
            }
            lastError = nil
        } catch {
            lastError = "Unable to remove the CueDex OpenCode plugin. Existing unowned files are never removed."
        }
        refresh()
    }

    func refreshPluginIfInstalled() {
        refresh()
        guard isInstalled else { return }
        do {
            let existing = try String(contentsOf: paths.opencodePluginURL, encoding: .utf8)
            guard existing.hasPrefix(Self.ownership) else { throw InstallerError.foreignFile }
            let generation = try String(contentsOf: paths.opencodeGateURL, encoding: .utf8)
            guard !generation.isEmpty else { return }
            let script = try Self.render(try pluginTemplate(), paths: paths, generation: generation)
            guard existing != script else { return }
            try script.write(to: paths.opencodePluginURL, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: paths.opencodePluginURL.path)
            lastError = nil
        } catch {
            lastError = "Unable to update the CueDex OpenCode plugin. Existing unowned files are never replaced."
        }
        refresh()
    }

    static func render(_ template: String, paths: CueDexPaths, generation: String) throws -> String {
        var result = template
        for (key, value) in [
            "EVENTS": paths.eventsDirectory.path(percentEncoded: false),
            "GATE": paths.opencodeGateURL.path(percentEncoded: false),
            "GENERATION": generation,
            "APP": paths.appBundle.path(percentEncoded: false),
        ] {
            let literal = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
            result = result.replacingOccurrences(of: "\"__CUEDEX_\(key)__\"", with: literal)
        }
        return result
    }

    nonisolated static func detectVersion() async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let environment = ProcessInfo.processInfo.environment
                let directories = (environment["PATH"] ?? "").components(separatedBy: ":")
                    .filter { $0.hasPrefix("/") }
                    + [FileManager.default.homeDirectoryForCurrentUser.appending(path: ".opencode/bin").path,
                       "/opt/homebrew/bin", "/usr/local/bin"]
                guard let executable = directories.map({ URL(filePath: $0).appending(path: "opencode") })
                    .first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
                    continuation.resume(returning: nil)
                    return
                }
                let process = Process()
                let output = Pipe()
                let finished = DispatchSemaphore(value: 0)
                process.executableURL = executable
                process.arguments = ["--version"]
                process.standardOutput = output
                process.standardError = FileHandle.nullDevice
                process.terminationHandler = { _ in finished.signal() }
                do {
                    try process.run()
                    guard finished.wait(timeout: .now() + 5) == .success else {
                        process.terminate()
                        continuation.resume(returning: nil)
                        return
                    }
                    let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                    let version = text.split(whereSeparator: \.isWhitespace).last.map(String.init)
                    continuation.resume(returning: process.terminationStatus == 0 ? version : nil)
                } catch { continuation.resume(returning: nil) }
            }
        }
    }

    private enum InstallerError: Error { case foreignFile }
}
