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

    private static let lastAutomaticCheckKey = "cuedex.updates.lastAutomaticCheck"
    let currentVersion: String
    private(set) var state: State = .idle
    private(set) var presentedRelease: AppRelease?

    private let client: GitHubReleaseClient
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.peter.CueDex", category: "Updates")

    init(
        currentVersion: String = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0",
        client: GitHubReleaseClient? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.currentVersion = currentVersion
        self.client = client ?? GitHubReleaseClient()
        self.defaults = defaults
    }

    func checkAutomaticallyIfNeeded(now: Date = Date()) async {
        let lastCheck = defaults.object(forKey: Self.lastAutomaticCheckKey) as? Date
        guard Self.shouldCheckAutomatically(lastCheck: lastCheck, now: now) else { return }

        defaults.set(now, forKey: Self.lastAutomaticCheckKey)
        await performCheck()
    }

    func checkManually() async {
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
        guard state != .checking else { return }
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
