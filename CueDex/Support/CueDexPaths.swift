import Foundation

struct CueDexPaths: Sendable {
    let applicationSupport: URL
    let codexHome: URL
    let appBundle: URL

    var eventsDirectory: URL {
        applicationSupport.appending(path: "Events", directoryHint: .isDirectory)
    }

    var diagnosticsDirectory: URL {
        applicationSupport.appending(path: "Diagnostics", directoryHint: .isDirectory)
    }

    var customSoundsDirectory: URL {
        applicationSupport.appending(path: "Sounds", directoryHint: .isDirectory)
    }

    var helperDirectory: URL {
        applicationSupport.appending(path: "bin", directoryHint: .isDirectory)
    }

    var helperURL: URL {
        helperDirectory.appending(path: "cuedex-notify")
    }

    var codexConfigURL: URL {
        codexHome.appending(path: "config.toml")
    }

    var codexHooksURL: URL {
        codexHome.appending(path: "hooks.json")
    }

    nonisolated static func live(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main
    ) -> CueDexPaths {
        let supportRoot = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let codexHome = environment["CODEX_HOME"].map { URL(filePath: $0, directoryHint: .isDirectory) }
            ?? fileManager.homeDirectoryForCurrentUser.appending(path: ".codex", directoryHint: .isDirectory)

        return CueDexPaths(
            applicationSupport: supportRoot.appending(path: "CueDex", directoryHint: .isDirectory),
            codexHome: codexHome,
            appBundle: bundle.bundleURL
        )
    }
}
