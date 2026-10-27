import AppKit
import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class UpdateController {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(AppRelease)
        case failed
    }

    enum DownloadState: Equatable {
        case idle
        case downloading(Double)
        case verifying
        case ready
        case opening
        case opened
        case failed(String)
    }

    private static let lastAutomaticCheckKey = "cuedex.updates.lastAutomaticCheck"
    let currentVersion: String
    private(set) var state: State = .idle
    private(set) var presentedRelease: AppRelease?
    private(set) var downloadRelease: AppRelease?
    private(set) var downloadState: DownloadState = .idle
    var isDownloadPresented = false

    private let client: GitHubReleaseClient
    private let defaults: UserDefaults
    private let downloader: DmgUpdateDownloader
    private let architecture: String
    private let openInstaller: (URL) throws -> Void
    @ObservationIgnored private var downloadTask: Task<Void, Never>?
    @ObservationIgnored private var operationID = UUID()
    private var downloadedUpdate: DownloadedUpdate?
    private let logger = Logger(subsystem: "com.peter.CueDex", category: "Updates")

    init(
        currentVersion: String = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0",
        client: GitHubReleaseClient? = nil,
        defaults: UserDefaults = .standard,
        downloader: DmgUpdateDownloader? = nil,
        architecture: String = DmgUpdateDownloader.architecture,
        openInstaller: @escaping (URL) throws -> Void = { url in
            guard NSWorkspace.shared.open(url) else { throw UpdateDownloadError.openFailed }
        }
    ) {
        self.currentVersion = currentVersion
        self.client = client ?? GitHubReleaseClient()
        self.defaults = defaults
        self.downloader = downloader ?? DmgUpdateDownloader(
            directory: CueDexPaths.live().applicationSupport.appending(path: "Updates", directoryHint: .isDirectory)
        )
        self.architecture = architecture
        self.openInstaller = openInstaller
    }

    var isDownloading: Bool {
        switch downloadState {
        case .downloading, .verifying, .opening: true
        default: false
        }
    }

    func canDownload(_ release: AppRelease) -> Bool {
        release.updatePackage(for: architecture) != nil
    }

    func presentDownload(for release: AppRelease) {
        guard !isDownloading || downloadRelease == release else { return }
        if downloadRelease != release {
            downloadRelease = release
            downloadState = .idle
            downloadedUpdate = nil
        }
        isDownloadPresented = true
        if downloadState == .idle { startDownload() }
    }

    func startDownload() {
        guard !isDownloading, let release = downloadRelease,
              let package = release.updatePackage(for: architecture) else { return }
        downloadedUpdate = nil
        downloadState = .downloading(0)
        let id = UUID()
        operationID = id
        downloadTask = Task {
            defer { if operationID == id { downloadTask = nil } }
            do {
                let update = try await downloader.download(package) { [self] progress in
                    Task { @MainActor in
                        guard self.operationID == id else { return }
                        switch (self.downloadState, progress) {
                        case (.downloading, .downloading(let value)):
                            self.downloadState = .downloading(value)
                        case (.downloading, .verifying):
                            self.downloadState = .verifying
                        default: break
                        }
                    }
                }
                guard operationID == id, !Task.isCancelled else { return }
                downloadedUpdate = update
                downloadState = .ready
            } catch {
                guard operationID == id, !Task.isCancelled else { return }
                downloadState = .failed(error is UpdateDownloadError
                    ? "Verification failed. The downloaded file does not match the release checksum."
                    : "Download failed. Check your network connection and try again.")
                logger.error("Update download failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func cancelDownload() {
        guard downloadTask != nil else { return }
        operationID = UUID()
        downloadTask?.cancel()
        downloadTask = nil
        downloadState = .idle
    }

    func openDownloadedInstaller() async {
        guard !isDownloading, let update = downloadedUpdate else { return }
        downloadState = .opening
        do {
            try await downloader.verify(update)
        } catch {
            downloadedUpdate = nil
            downloadState = .failed("Verification failed. The downloaded file does not match the release checksum.")
            return
        }
        do {
            try openInstaller(update.url)
            downloadState = .opened
        } catch {
            downloadState = .failed("Unable to open the installer. You can view the release to download it manually.")
        }
    }

    func checkAutomaticallyIfNeeded(now: Date = Date()) async {
        let lastCheck = defaults.object(forKey: Self.lastAutomaticCheckKey) as? Date
        guard Self.shouldCheckAutomatically(lastCheck: lastCheck, now: now) else { return }

        defaults.set(now, forKey: Self.lastAutomaticCheckKey)
        await performCheck()
    }

    func checkManually() async {
        guard !isDownloading else { return }
        await performCheck()
        if state != .failed {
            defaults.set(Date(), forKey: Self.lastAutomaticCheckKey)
        }
    }

    func dismissUpdateAlert() {
        presentedRelease = nil
    }

    nonisolated static func shouldCheckAutomatically(
        lastCheck: Date?,
        now: Date,
        interval: TimeInterval = 24 * 60 * 60
    ) -> Bool {
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= interval
    }

    private func performCheck() async {
        guard state != .checking, !isDownloading else { return }
        state = .checking

        do {
            let release = try await client.fetchLatestRelease()
            if AppVersion.isNewer(release.version, than: currentVersion) {
                state = .updateAvailable(release)
                presentedRelease = release
            } else {
                state = .upToDate
            }
            logger.info("Finished update check for version \(self.currentVersion, privacy: .public)")
        } catch {
            state = .failed
            logger.error("Update check failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
