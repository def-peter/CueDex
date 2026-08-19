import AppKit
import Observation
import OSLog

@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    let preferences: PreferencesStore
    let integration: CodexIntegrationInstaller
    let loginItem: LoginItemController

    private let logger = Logger(subsystem: "com.peter.CueDex", category: "App")
    private let glowController = ScreenGlowController()
    private let soundController = SoundController()
    private let speechController = SpeechController()
    private let eventMonitor: CodexEventMonitor
    private let runtimeServicesEnabled: Bool
    private var hasStarted = false

    init(
        paths: CueDexPaths = .live(),
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        runtimeServicesEnabled: Bool = AppModel.shouldStartRuntimeServices()
    ) {
        preferences = PreferencesStore(
            defaults: defaults,
            customSoundStorage: CustomSoundStorage(
                directory: paths.customSoundsDirectory,
                fileManager: fileManager
            )
        )
        integration = CodexIntegrationInstaller(paths: paths, fileManager: fileManager, defaults: defaults)
        loginItem = LoginItemController()
        eventMonitor = CodexEventMonitor(eventsDirectory: paths.eventsDirectory, fileManager: fileManager)
        self.runtimeServicesEnabled = runtimeServicesEnabled
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        guard runtimeServicesEnabled else {
            logger.info("Skipped runtime services in the test environment")
            return
        }
        integration.refresh()
#if !DEBUG
        integration.refreshHelperIfInstalled()
#endif

        do {
            try eventMonitor.start { [weak self] in
                self?.handleCodexCompletion()
            }
        } catch {
            logger.error("Event monitor failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    nonisolated static func shouldStartRuntimeServices(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        if environment["CUEDEX_DISABLE_RUNTIME_SERVICES"] == "1" {
            return false
        }
        let testEnvironmentKeys = [
            "XCTestConfigurationFilePath",
            "XCTestBundlePath",
            "XCInjectBundleInto",
        ]
        return !testEnvironmentKeys.contains { environment[$0] != nil }
    }

    func handleCodexCompletion() {
        guard preferences.shouldDeliver() else {
            logger.info("Suppressed completion cue due to pause or quiet hours")
            return
        }
        deliverCue()
    }

    func testCue() {
        deliverCue()
    }

    func testGlow() {
        guard preferences.glowEnabled else { return }
        glowController.show(glowPresentation)
    }

    func testSound() {
        guard preferences.soundEnabled else { return }
        soundController.play(preferences: preferences.preferences)
    }

    func testSpeech() {
        guard preferences.speechEnabled else { return }
        speechController.speak(
            preferences.speechText,
            voiceIdentifier: preferences.speechVoiceIdentifier
        )
    }

    private func deliverCue() {
        if preferences.glowEnabled {
            glowController.show(glowPresentation)
        }
        if preferences.soundEnabled {
            soundController.play(preferences: preferences.preferences)
        }
        if preferences.speechEnabled {
            speechController.speak(
                preferences.speechText,
                voiceIdentifier: preferences.speechVoiceIdentifier
            )
        }
        logger.info("Delivered completion cue")
    }

    private var glowPresentation: GlowPresentation {
        let settings = preferences.preferences
        let primaryColor: NSColor
        switch settings.glowAnimation {
        case .breathing:
            primaryColor = NSColor(
                red: settings.glowRed,
                green: settings.glowGreen,
                blue: settings.glowBlue,
                alpha: 1
            )
        case .alternatingFlash:
            primaryColor = NSColor(
                red: settings.glowFlashPrimaryRed,
                green: settings.glowFlashPrimaryGreen,
                blue: settings.glowFlashPrimaryBlue,
                alpha: 1
            )
        }

        return GlowPresentation(
            primaryColor: primaryColor,
            secondaryColor: NSColor(
                red: settings.glowSecondaryRed,
                green: settings.glowSecondaryGreen,
                blue: settings.glowSecondaryBlue,
                alpha: 1
            ),
            intensity: settings.glowIntensity,
            duration: settings.glowDuration,
            animation: settings.glowAnimation
        )
    }
}
