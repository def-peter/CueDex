import Foundation
import Observation

@MainActor
@Observable
final class OpenCodeIntegrationInstaller {
    static let supportedVersion = "2.1.1"
    private static let ownership = "// CueDex managed OpenCode V2 bridge."
    let paths: CueDexPaths
    private let fileManager: FileManager
    private let versionProvider: @Sendable () async -> String?
    private let pluginTemplate: () throws -> String
    private(set) var isInstalled = false
    private(set) var isCheckingVersion = false
    private(set) var detectedVersion: String?
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
        isCheckingVersion = false
    }

    func install() async {
        await checkVersion()
        guard detectedVersion == Self.supportedVersion else {
            lastError = "Only OpenCode V2.1.1 is verified. Install that version before enabling integration."
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
                    let version = text.split(whereSeparator: \.isWhitespace).last.map(String.init)?
                        .replacingOccurrences(of: "v", with: "")
                    continuation.resume(returning: process.terminationStatus == 0 ? version : nil)
                } catch { continuation.resume(returning: nil) }
            }
        }
    }

    private enum InstallerError: Error { case foreignFile }
}
