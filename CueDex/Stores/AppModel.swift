import AppKit
import Observation
import OSLog

@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    let preferences: PreferencesStore
    let integration: CodexIntegrationInstaller
    let opencodeIntegration: OpenCodeIntegrationInstaller
    let loginItem: LoginItemController
    let updates: UpdateController
    private(set) var lastReceived: [AttentionSource: Date] = [:]
    private(set) var isPlayingCue = false

    private let logger = Logger(subsystem: "com.peter.CueDex", category: "App")
    private let playback: any CuePlaying
    private let eventMonitor: CueEventMonitor
    private let defaults: UserDefaults
    private let runtimeServicesEnabled: Bool
    private var hasStarted = false
    @ObservationIgnored private var queue = CueEventQueue()
    @ObservationIgnored private var activeSource: AttentionSource?
    @ObservationIgnored private var isPreviewing = false
    @ObservationIgnored private var policyTask: Task<Void, Never>?
    @ObservationIgnored private var deliveryWasSuppressed = false
    @ObservationIgnored private var resumedAt: Date?
    @ObservationIgnored private var sourceCutoffs: [AttentionSource: Date] = [:]

    init(
        paths: CueDexPaths = .live(),
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        runtimeServicesEnabled: Bool = AppModel.shouldStartRuntimeServices(),
        playback: (any CuePlaying)? = nil
    ) {
        preferences = PreferencesStore(
            defaults: defaults,
            customSoundStorage: CustomSoundStorage(directory: paths.customSoundsDirectory, fileManager: fileManager)
        )
        integration = CodexIntegrationInstaller(paths: paths, fileManager: fileManager, defaults: defaults)
        opencodeIntegration = OpenCodeIntegrationInstaller(paths: paths, fileManager: fileManager)
        loginItem = LoginItemController()
        updates = UpdateController(defaults: defaults)
        eventMonitor = CueEventMonitor(eventsDirectory: paths.eventsDirectory, fileManager: fileManager)
        self.defaults = defaults
        self.runtimeServicesEnabled = runtimeServicesEnabled
        self.playback = playback ?? CuePlaybackController()
        for source in AttentionSource.allCases {
            lastReceived[source] = defaults.object(forKey: "cuedex.last-event.\(source.rawValue)") as? Date
            sourceCutoffs[source] = defaults.object(forKey: "cuedex.source-cutoff.\(source.rawValue)") as? Date
        }
        resumedAt = defaults.object(forKey: "cuedex.resumed-at") as? Date
        deliveryWasSuppressed = !preferences.shouldDeliver()
        preferences.deliveryPolicyDidChange = { [weak self] in self?.enforceDeliveryPolicy() }
    }

    deinit { policyTask?.cancel() }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        guard runtimeServicesEnabled else { return }
        integration.refresh()
        opencodeIntegration.refresh()
#if !DEBUG
        integration.refreshHelperIfInstalled()
        opencodeIntegration.refreshPluginIfInstalled()
#endif
        Task { await updates.checkAutomaticallyIfNeeded() }
        Task { await opencodeIntegration.checkVersion() }
        do {
            try eventMonitor.start { [weak self] event in self?.handleCompletion(event) }
        } catch {
            logger.error("Local event monitor could not start")
        }
        // Quiet-hour boundaries have minute precision; no filesystem polling.
        policyTask = Task { [weak self] in
            while !Task.isCancelled {
                let delay = 60 - Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 60)
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                self?.enforceDeliveryPolicy()
            }
        }
    }

    nonisolated static func shouldStartRuntimeServices(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        if environment["CUEDEX_DISABLE_RUNTIME_SERVICES"] == "1" { return false }
        return !["XCTestConfigurationFilePath", "XCTestBundlePath", "XCInjectBundleInto"]
            .contains { environment[$0] != nil }
    }

    func isInstalled(_ source: AttentionSource) -> Bool {
        source == .codex ? integration.isInstalled : opencodeIntegration.isInstalled
    }

    func enableIntegration(_ source: AttentionSource) async {
        let wasInstalled = isInstalled(source)
        switch source {
        case .codex: integration.install()
        case .opencode: await opencodeIntegration.install()
        }
        if !wasInstalled && isInstalled(source) { updateCutoff(for: source) }
    }

    func disableIntegration(_ source: AttentionSource) {
        updateCutoff(for: source)
        switch source {
        case .codex: integration.uninstall()
        case .opencode: opencodeIntegration.uninstall()
        }
        queue.remove(source: source)
        if activeSource == source && !isPreviewing { stopPlayback() }
        playNext()
    }

    func handleCompletion(_ event: CueEvent) {
        enforceDeliveryPolicy()
        let installed = isInstalled(event.source)
        let accepted = queue.receive(event, deliver: installed && preferences.shouldDeliver()
            && preferences.shouldDeliver(at: event.completedAt) && isAfterCutoff(event))
        guard accepted else { return }
        if installed {
            let latest = max(lastReceived[event.source] ?? .distantPast, event.completedAt)
            lastReceived[event.source] = latest
            defaults.set(latest, forKey: "cuedex.last-event.\(event.source.rawValue)")
        }
        playNext()
    }

    func testCue(source: AttentionSource) { preview(source: source, effect: .all) }
    func testGlow() { preview(source: preferences.selectedSource, effect: .glow) }
    func testSound() { preview(source: preferences.selectedSource, effect: .sound) }
    func testSpeech() { preview(source: preferences.selectedSource, effect: .speech) }

    private func preview(source: AttentionSource, effect: CuePlaybackController.Preview) {
        guard !isPlayingCue else { return }
        isPreviewing = true
        activeSource = source
        isPlayingCue = true
        playback.play(preferences.profile(for: source), preview: effect) { [weak self] in
            self?.didFinishPlayback()
        }
    }

    private func enforceDeliveryPolicy() {
        let suppressed = !preferences.shouldDeliver()
        if deliveryWasSuppressed && !suppressed {
            resumedAt = .now
            defaults.set(resumedAt, forKey: "cuedex.resumed-at")
        }
        deliveryWasSuppressed = suppressed
        if suppressed {
            queue.clear()
            if !isPreviewing { stopPlayback() }
        }
    }

    private func playNext() {
        guard !isPlayingCue else { return }
        guard preferences.shouldDeliver() else { queue.clear(); return }
        while let event = queue.next() {
            guard isInstalled(event.source), isAfterCutoff(event) else { continue }
            activeSource = event.source
            isPreviewing = false
            isPlayingCue = true
            playback.play(preferences.profile(for: event.source), preview: .all) { [weak self] in self?.didFinishPlayback() }
            return
        }
    }

    private func didFinishPlayback() {
        isPlayingCue = false
        activeSource = nil
        isPreviewing = false
        playNext()
    }

    private func stopPlayback() {
        playback.stop()
        isPlayingCue = false
        activeSource = nil
        isPreviewing = false
    }

    private func updateCutoff(for source: AttentionSource) {
        sourceCutoffs[source] = .now
        defaults.set(sourceCutoffs[source], forKey: "cuedex.source-cutoff.\(source.rawValue)")
    }

    private func isAfterCutoff(_ event: CueEvent) -> Bool {
        event.completedAt >= (resumedAt ?? .distantPast)
            && event.completedAt >= (sourceCutoffs[event.source] ?? .distantPast)
    }
}
