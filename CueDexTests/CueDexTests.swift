import AVFoundation
import AppKit
import Foundation
import SwiftUI
import Testing
@testable import CueDex

struct CueDexTests {
    @Test @MainActor func menuBarAppConfigurationIsBundled() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool == true)
        #expect(NSImage(named: "MenuBarIcon") != nil)
        #expect(NSImage(named: "MenuBarIconPaused") != nil)
    }

    @Test func releaseVersionsCompareNumerically() {
        #expect(AppVersion.isNewer("v1.0.10", than: "1.0.9"))
        #expect(!AppVersion.isNewer("v1.0.2", than: "1.0.2"))
        #expect(!AppVersion.isNewer("v1.0.1", than: "1.0.2"))
    }

    @Test func githubReleaseResponseIsDecoded() throws {
        let data = try #require(
            #"{"tag_name":"v1.2.3","html_url":"https://github.com/def-peter/CueDex/releases/tag/v1.2.3"}"#
                .data(using: .utf8)
        )

        let release = try GitHubReleaseClient.decodeRelease(from: data)

        #expect(release.version == "1.2.3")
        #expect(release.pageURL.absoluteString.hasSuffix("/v1.2.3"))
    }

    @Test func automaticUpdateChecksAreLimitedToOncePerDay() {
        let now = Date(timeIntervalSince1970: 2_000_000)

        #expect(UpdateController.shouldCheckAutomatically(lastCheck: nil, now: now))
        #expect(!UpdateController.shouldCheckAutomatically(lastCheck: now.addingTimeInterval(-60), now: now))
        #expect(UpdateController.shouldCheckAutomatically(lastCheck: now.addingTimeInterval(-86_400), now: now))
    }

    @Test func quietHoursAcrossMidnight() throws {
        var preferences = CuePreferences.defaults
        preferences.quietHoursEnabled = true
        preferences.quietHoursStartMinutes = 22 * 60
        preferences.quietHoursEndMinutes = 8 * 60

        let calendar = Calendar(identifier: .gregorian)
        let late = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 18, hour: 23)))
        let early = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 19, hour: 7)))
        let daytime = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 19, hour: 12)))

        #expect(preferences.isQuiet(at: late, calendar: calendar))
        #expect(preferences.isQuiet(at: early, calendar: calendar))
        #expect(!preferences.isQuiet(at: daytime, calendar: calendar))
    }

    @Test @MainActor func olderPreferencesGainSpeechDefaultsWithoutLosingValues() throws {
        let data = try #require(#"{"soundEnabled":false,"soundVolume":0.25}"#.data(using: .utf8))

        let preferences = try JSONDecoder().decode(CuePreferences.self, from: data)

        #expect(!preferences.soundEnabled)
        #expect(preferences.soundVolume == 0.25)
        #expect(!preferences.speechEnabled)
        #expect(preferences.appLanguage == .simplifiedChinese)
        #expect(preferences.speechText == "Codex 已回复完成。")
        #expect(preferences.glowEnabled)
        #expect(preferences.glowAnimation == .breathing)
        #expect(preferences.glowFlashPrimaryRed == 1.0)
        #expect(preferences.glowFlashPrimaryGreen == 0.08)
        #expect(preferences.glowFlashPrimaryBlue == 0.12)
        #expect(preferences.glowSecondaryRed == 0.15)
        #expect(preferences.glowSecondaryGreen == 0.48)
        #expect(preferences.glowSecondaryBlue == 1.0)
        #expect(preferences.speechVoiceIdentifier == nil)
    }

    @Test @MainActor func legacySoftFlashMigratesToBreathing() throws {
        let data = try #require(#"{"glowAnimation":"softFlash","glowDuration":3.2}"#.data(using: .utf8))

        let preferences = try JSONDecoder().decode(CuePreferences.self, from: data)

        #expect(preferences.glowAnimation == .breathing)
        #expect(preferences.glowDuration == 3.2)
    }

    @Test @MainActor func legacyMarqueeMigratesToAlternatingFlash() throws {
        let data = try #require(#"{"glowAnimation":"marquee"}"#.data(using: .utf8))

        let preferences = try JSONDecoder().decode(CuePreferences.self, from: data)

        #expect(preferences.glowAnimation == .alternatingFlash)
    }

    @Test @MainActor func alternatingFlashPreferencesPersist() throws {
        let suiteName = "CueDexAlternatingFlashTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PreferencesStore(defaults: defaults)
        store.glowAnimation = .alternatingFlash
        store.breathingGlowColor = Color(red: 0.1, green: 0.2, blue: 0.3)
        store.flashPrimaryColor = Color(red: 0.9, green: 0.1, blue: 0.2)
        store.flashSecondaryColor = Color(red: 0.2, green: 0.3, blue: 0.9)
        let stored = store.preferences

        let restored = PreferencesStore(defaults: defaults)
        #expect(restored.glowAnimation == .alternatingFlash)
        #expect(abs(restored.preferences.glowRed - stored.glowRed) < 0.001)
        #expect(abs(restored.preferences.glowGreen - stored.glowGreen) < 0.001)
        #expect(abs(restored.preferences.glowBlue - stored.glowBlue) < 0.001)
        #expect(abs(restored.preferences.glowFlashPrimaryRed - stored.glowFlashPrimaryRed) < 0.001)
        #expect(abs(restored.preferences.glowFlashPrimaryGreen - stored.glowFlashPrimaryGreen) < 0.001)
        #expect(abs(restored.preferences.glowFlashPrimaryBlue - stored.glowFlashPrimaryBlue) < 0.001)
        #expect(abs(restored.preferences.glowSecondaryRed - stored.glowSecondaryRed) < 0.001)
        #expect(abs(restored.preferences.glowSecondaryGreen - stored.glowSecondaryGreen) < 0.001)
        #expect(abs(restored.preferences.glowSecondaryBlue - stored.glowSecondaryBlue) < 0.001)
    }

    @Test @MainActor func existingGlowColorsMigrateToIndependentFlashColors() throws {
        let data = try #require(
            #"{"glowRed":0.7,"glowGreen":0.6,"glowBlue":0.5,"glowSecondaryRed":0.4,"glowSecondaryGreen":0.3,"glowSecondaryBlue":0.2}"#
                .data(using: .utf8)
        )

        let preferences = try JSONDecoder().decode(CuePreferences.self, from: data)

        #expect(preferences.glowFlashPrimaryRed == 0.7)
        #expect(preferences.glowFlashPrimaryGreen == 0.6)
        #expect(preferences.glowFlashPrimaryBlue == 0.5)
        #expect(preferences.glowSecondaryRed == 0.4)
        #expect(preferences.glowSecondaryGreen == 0.3)
        #expect(preferences.glowSecondaryBlue == 0.2)
    }

    @Test @MainActor func languagePersistsAndOnlyUpdatesDefaultSpeechText() throws {
        let suiteName = "CueDexLanguageTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PreferencesStore(defaults: defaults)
        #expect(store.appLanguage == .simplifiedChinese)
        #expect(store.speechText == "Codex 已回复完成。")

        store.appLanguage = .english
        #expect(store.speechText == "Codex has finished responding.")

        store.speechText = "My custom message"
        store.appLanguage = .simplifiedChinese

        let restored = PreferencesStore(defaults: defaults)
        #expect(restored.appLanguage == .simplifiedChinese)
        #expect(restored.speechText == "My custom message")
    }

    @Test func simplifiedChineseLocalizationIsBundled() throws {
        let localizationURL = try #require(
            Bundle.main.url(forResource: "zh-Hans", withExtension: "lproj")
        )
        let localizationBundle = try #require(Bundle(url: localizationURL))

        #expect(localizationBundle.localizedString(forKey: "General", value: nil, table: nil) == "通用")
        #expect(localizationBundle.localizedString(forKey: "Test Cue", value: nil, table: nil) == "测试提示")
        #expect(localizationBundle.localizedString(forKey: "Two-Color Flash", value: nil, table: nil) == "双色交替闪烁")
        #expect(localizationBundle.localizedString(forKey: "Pause notifications", value: nil, table: nil) == "暂停通知")
        #expect(localizationBundle.localizedString(forKey: "Search voices", value: nil, table: nil) == "搜索说话人")
        #expect(localizationBundle.localizedString(forKey: "System Default", value: nil, table: nil) == "系统默认")
        #expect(localizationBundle.localizedString(forKey: "Quiet Hours", value: nil, table: nil) == "免打扰")
        #expect(localizationBundle.localizedString(forKey: "About", value: nil, table: nil) == "关于")
        #expect(localizationBundle.localizedString(forKey: "Author", value: nil, table: nil) == "作者")
        #expect(localizationBundle.localizedString(forKey: "Feedback Email", value: nil, table: nil) == "反馈邮箱")
        #expect(localizationBundle.localizedString(forKey: "Build", value: nil, table: nil) == "构建")
        #expect(localizationBundle.localizedString(forKey: "Updates", value: nil, table: nil) == "更新")
        #expect(localizationBundle.localizedString(forKey: "Check for Updates", value: nil, table: nil) == "检查更新")
        #expect(localizationBundle.localizedString(forKey: "Update Available", value: nil, table: nil) == "发现新版本")
        #expect(
            localizationBundle.localizedString(
                forKey: "CueDex notifies you with screen-edge glow, sound, or speech when Codex finishes responding.",
                value: nil,
                table: nil
            ) == "当 Codex 完成回复时，CueDex 会通过屏幕边缘光效、提示音或语音及时提醒你。"
        )
        #expect(localizationBundle.localizedString(forKey: "Remove Custom Sound", value: nil, table: nil) == "移除自定义音频")
        #expect(
            localizationBundle.localizedString(forKey: "Unable to import audio file.", value: nil, table: nil)
                == "无法导入音频文件。"
        )
        #expect(
            localizationBundle.localizedString(forKey: "Message Reminder (Male Voice)", value: nil, table: nil)
                == "快看我消息（男）"
        )
        #expect(
            localizationBundle.localizedString(forKey: "Message Reminder (Female Voice)", value: nil, table: nil)
                == "快看我消息（女）"
        )
    }

    @Test @MainActor func bundledNotificationSoundsArePackaged() throws {
        #expect(
            Set(SoundController.bundledSounds.map(\.id)) == [
                "bundled.message-reminder-male",
                "bundled.message-reminder-female",
            ]
        )

        for option in SoundController.bundledSounds {
            let url = try #require(SoundController.bundledSoundURL(for: option.id))
            #expect(url.pathExtension == "wav")
            #expect(try Data(contentsOf: url).count > 32_000)
        }
    }

    @Test @MainActor func missingCustomSoundDoesNotRemainSelected() throws {
        let suiteName = "CueDexMissingCustomSoundTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var stored = CuePreferences.defaults
        stored.soundIdentifier = "custom"
        stored.customSoundPath = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appendingPathExtension("wav")
            .path
        defaults.set(try JSONEncoder().encode(stored), forKey: "cuedex.preferences.v1")

        let restored = PreferencesStore(defaults: defaults)

        #expect(restored.customSoundPath == nil)
        #expect(restored.soundIdentifier == "Glass")
    }

    @Test @MainActor func importedCustomSoundSurvivesSourceDeletionAndCanBeRemoved() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let sourceURL = root.appending(path: "My Alert.wav")
        let managedDirectory = root.appending(path: "Managed", directoryHint: .isDirectory)
        let suiteName = "CueDexManagedCustomSoundTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            try? fileManager.removeItem(at: root)
            defaults.removePersistentDomain(forName: suiteName)
        }

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(repeating: 0x7f, count: 128).write(to: sourceURL)
        let storage = CustomSoundStorage(directory: managedDirectory, fileManager: fileManager)
        let store = PreferencesStore(defaults: defaults, customSoundStorage: storage)

        try store.setCustomSound(sourceURL)
        let managedPath = try #require(store.customSoundPath)
        #expect(managedPath != sourceURL.path)
        #expect(store.customSoundName == "My Alert")
        #expect(store.soundIdentifier == "custom")
        #expect(fileManager.fileExists(atPath: managedPath))

        try fileManager.removeItem(at: sourceURL)
        let restored = PreferencesStore(defaults: defaults, customSoundStorage: storage)
        #expect(restored.customSoundPath == managedPath)
        #expect(restored.customSoundName == "My Alert")
        #expect(restored.soundIdentifier == "custom")

        restored.removeCustomSound()
        #expect(restored.customSoundPath == nil)
        #expect(restored.customSoundName == nil)
        #expect(restored.soundIdentifier == "Glass")
        #expect(!fileManager.fileExists(atPath: managedPath))
    }

    @Test @MainActor func existingLegacyCustomSoundIsMigratedIntoManagedStorage() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let sourceURL = root.appending(path: "Legacy Alert.aiff")
        let managedDirectory = root.appending(path: "Managed", directoryHint: .isDirectory)
        let suiteName = "CueDexLegacyCustomSoundTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            try? fileManager.removeItem(at: root)
            defaults.removePersistentDomain(forName: suiteName)
        }

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(repeating: 0x3f, count: 128).write(to: sourceURL)
        var stored = CuePreferences.defaults
        stored.soundIdentifier = "custom"
        stored.customSoundPath = sourceURL.path
        defaults.set(try JSONEncoder().encode(stored), forKey: "cuedex.preferences.v1")

        let storage = CustomSoundStorage(directory: managedDirectory, fileManager: fileManager)
        let restored = PreferencesStore(defaults: defaults, customSoundStorage: storage)
        let managedPath = try #require(restored.customSoundPath)

        #expect(managedPath != sourceURL.path)
        #expect(managedPath.hasPrefix(managedDirectory.path))
        #expect(restored.customSoundName == "Legacy Alert")
        #expect(fileManager.fileExists(atPath: sourceURL.path))
        #expect(fileManager.fileExists(atPath: managedPath))
    }

    @Test @MainActor func speechVoiceSearchSupportsPartialAndFuzzyNames() {
        let voice = SpeechVoiceOption(
            id: "com.apple.voice.compact.zh-CN.Tingting",
            name: "Tingting",
            language: "zh-CN"
        )
        let accentedVoice = SpeechVoiceOption(
            id: "com.apple.voice.compact.fr-CA.Amelie",
            name: "Amélie",
            language: "fr-CA"
        )

        #expect(voice.matchScore(for: "ting") != nil)
        #expect(voice.matchScore(for: "TNGTNG") != nil)
        #expect(voice.matchScore(for: "zhcn") != nil)
        #expect(accentedVoice.matchScore(for: "amelie") != nil)
        #expect(voice.matchScore(for: "alice") == nil)
    }

    @Test @MainActor func speechUtterancePreservesNotificationText() {
        let text = "Finished; touch /tmp/should-not-exist"

        let utterance = SpeechController.makeUtterance(text: text)

        #expect(utterance.speechString == text)
        #expect(utterance.voice == nil)
    }

    @Test @MainActor func speechUtteranceUsesSelectedSystemVoice() throws {
        let text = "Finished; touch /tmp/should-not-exist"
        let voice = try #require(SpeechVoiceCatalog.voices.first)

        let utterance = SpeechController.makeUtterance(text: text, voiceIdentifier: voice.id)

        #expect(utterance.speechString == text)
        #expect(utterance.voice?.identifier == voice.id)
    }

    @Test @MainActor func speechPreferencesPersist() throws {
        let suiteName = "CueDexSpeechTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PreferencesStore(defaults: defaults)
        store.speechEnabled = true
        store.speechText = "The response is ready."
        store.speechVoiceIdentifier = "com.apple.voice.compact.en-US.Samantha"

        let restored = PreferencesStore(defaults: defaults)
        #expect(restored.speechEnabled)
        #expect(restored.speechText == "The response is ready.")
        #expect(restored.speechVoiceIdentifier == "com.apple.voice.compact.en-US.Samantha")
    }

    @Test func stopHookIsAddedWithoutReplacingExistingHooks() throws {
        let helperPath = "/tmp/CueDex Support/cuedex-notify"
        let original = try #require(
            #"{"description":"existing","hooks":{"Stop":[{"hooks":[{"type":"command","command":"/tmp/existing"}]}],"SessionStart":[{"hooks":[{"type":"command","command":"/tmp/start"}]}]}}"#
                .data(using: .utf8)
        )

        let updated = try CodexIntegrationInstaller.addingStopHook(
            to: original,
            helperPath: helperPath
        )

        #expect(try CodexIntegrationInstaller.containsStopHook(in: updated, helperPath: helperPath))
        let root = try #require(JSONSerialization.jsonObject(with: updated) as? [String: Any])
        let hooks = try #require(root["hooks"] as? [String: Any])
        let stopGroups = try #require(hooks["Stop"] as? [[String: Any]])
        let sessionGroups = try #require(hooks["SessionStart"] as? [[String: Any]])
        #expect(stopGroups.count == 2)
        #expect(sessionGroups.count == 1)
        #expect(root["description"] as? String == "existing")
    }

    @Test func removingStopHookPreservesOtherHandlers() throws {
        let helperPath = "/tmp/cuedex-notify"
        let original = try #require(
            #"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"/tmp/existing"},{"type":"command","command":"'/tmp/cuedex-notify'"}]}]}}"#
                .data(using: .utf8)
        )

        let removed = try CodexIntegrationInstaller.removingStopHook(
            from: original,
            helperPath: helperPath
        )
        let updated = try #require(removed)

        #expect(try !CodexIntegrationInstaller.containsStopHook(in: updated, helperPath: helperPath))
        let root = try #require(JSONSerialization.jsonObject(with: updated) as? [String: Any])
        let hooks = try #require(root["hooks"] as? [String: Any])
        let stopGroups = try #require(hooks["Stop"] as? [[String: Any]])
        let handlers = try #require(stopGroups.first?["hooks"] as? [[String: Any]])
        #expect(handlers.count == 1)
        #expect(handlers.first?["command"] as? String == "/tmp/existing")
    }

    @Test func invalidStopHookStructureIsRejected() throws {
        let invalid = try #require(#"{"hooks":{"Stop":"invalid"}}"#.data(using: .utf8))

        #expect(throws: CodexIntegrationError.invalidHooksFile) {
            try CodexIntegrationInstaller.addingStopHook(to: invalid, helperPath: "/tmp/cuedex-notify")
        }
    }

    @Test func removingNotifierRestoresPreviousValue() throws {
        let helper = "/tmp/cuedex-notify"
        let managed = "notify = [\"\(helper)\"]\nmodel = \"gpt-5.6-sol\"\n"
        let previous = "notify = [\"/tmp/existing\"]"

        let restored = CodexIntegrationInstaller.removingManagedNotifier(
            from: managed,
            helperPath: helper,
            restoring: previous
        )

        #expect(restored.hasPrefix(previous))
        #expect(!restored.contains(helper))
    }

    @Test @MainActor func helperOnlyCreatesEventsForMainStopWithANewAssistantMessage() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let codexHome = root.appending(path: ".codex", directoryHint: .isDirectory)
        let support = root.appending(path: "support", directoryHint: .isDirectory)
        let appBundle = root.appending(path: "Missing-CueDex.app", directoryHint: .isDirectory)
        let suiteName = "CueDexHookTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            try? fileManager.removeItem(at: root)
            defaults.removePersistentDomain(forName: suiteName)
        }

        let installer = CodexIntegrationInstaller(
            paths: CueDexPaths(applicationSupport: support, codexHome: codexHome, appBundle: appBundle),
            fileManager: fileManager,
            defaults: defaults
        )
        installer.install()

        func runHelper(with payload: String) throws -> Int32 {
            let process = Process()
            let standardInput = Pipe()
            process.executableURL = installer.paths.helperURL
            process.standardInput = standardInput
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            try process.run()
            standardInput.fileHandleForWriting.write(Data(payload.utf8))
            try standardInput.fileHandleForWriting.close()
            process.waitUntilExit()
            return process.terminationStatus
        }

        func completionEvents() throws -> [URL] {
            try fileManager.contentsOfDirectory(
                at: installer.paths.eventsDirectory,
                includingPropertiesForKeys: nil
            ).filter { $0.lastPathComponent.hasPrefix("turn-complete.") }
        }

        #expect(try runHelper(with: #"{"hook_event_name":"SubagentStop","agent_id":"child"}"#) == 0)
        #expect(try completionEvents().isEmpty)

        #expect(try runHelper(with: #"{"hook_event_name":"Stop","turn_id":"main"}"#) == 0)
        #expect(try completionEvents().isEmpty)

        let completedTurn = #"{"hook_event_name":"Stop","turn_id":"main","last_assistant_message":"Done"}"#
        #expect(try runHelper(with: completedTurn) == 0)
        #expect(try completionEvents().count == 1)

        #expect(try runHelper(with: completedTurn) == 0)
        #expect(try completionEvents().count == 1)
    }

    @Test @MainActor func startingDebugAppDoesNotRewriteAnInstalledHelper() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let codexHome = root.appending(path: ".codex", directoryHint: .isDirectory)
        let support = root.appending(path: "support", directoryHint: .isDirectory)
        let installedApp = root.appending(path: "Applications/CueDex.app", directoryHint: .isDirectory)
        let debugApp = root.appending(path: "DerivedData/CueDex.app", directoryHint: .isDirectory)
        let suiteName = "CueDexAppStartTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            try? fileManager.removeItem(at: root)
            defaults.removePersistentDomain(forName: suiteName)
        }

        let installedPaths = CueDexPaths(
            applicationSupport: support,
            codexHome: codexHome,
            appBundle: installedApp
        )
        let installer = CodexIntegrationInstaller(
            paths: installedPaths,
            fileManager: fileManager,
            defaults: defaults
        )
        installer.install()
        let installedHelper = try String(contentsOf: installedPaths.helperURL, encoding: .utf8)

        let debugModel = AppModel(
            paths: CueDexPaths(applicationSupport: support, codexHome: codexHome, appBundle: debugApp),
            defaults: defaults,
            fileManager: fileManager,
            runtimeServicesEnabled: true
        )
        debugModel.start()

        #expect(try String(contentsOf: installedPaths.helperURL, encoding: .utf8) == installedHelper)
        #expect(!installedHelper.contains(debugApp.path))
    }

    @Test func runtimeServicesAreDisabledForTestEnvironments() {
        #expect(AppModel.shouldStartRuntimeServices(environment: [:]))
        #expect(!AppModel.shouldStartRuntimeServices(
            environment: ["CUEDEX_DISABLE_RUNTIME_SERVICES": "1"]
        ))
        #expect(!AppModel.shouldStartRuntimeServices(
            environment: ["XCTestConfigurationFilePath": "/tmp/test.xctestconfiguration"]
        ))
    }

    @Test func completionEventsExpireAfterOneMinute() {
        let now = Date()

        #expect(CodexEventMonitor.isFreshEvent(
            modifiedAt: now.addingTimeInterval(-59),
            now: now,
            freshnessInterval: 60
        ))
        #expect(!CodexEventMonitor.isFreshEvent(
            modifiedAt: now.addingTimeInterval(-61),
            now: now,
            freshnessInterval: 60
        ))
    }

    @Test @MainActor func installerPreservesExistingHooksAndNotifier() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let codexHome = root.appending(path: ".codex", directoryHint: .isDirectory)
        let support = root.appending(path: "support", directoryHint: .isDirectory)
        let appBundle = root.appending(path: "CueDex.app", directoryHint: .isDirectory)
        let suiteName = "CueDexTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            try? fileManager.removeItem(at: root)
            defaults.removePersistentDomain(forName: suiteName)
        }

        try fileManager.createDirectory(at: codexHome, withIntermediateDirectories: true)
        let originalConfig = "notify = [\"/tmp/existing\"]\nmodel = \"gpt-5.6-sol\"\n"
        try originalConfig.write(to: codexHome.appending(path: "config.toml"), atomically: true, encoding: .utf8)
        let originalHooks = try #require(
            #"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"/tmp/existing-hook"}]}]}}"#
                .data(using: .utf8)
        )
        try originalHooks.write(to: codexHome.appending(path: "hooks.json"), options: .atomic)

        let installer = CodexIntegrationInstaller(
            paths: CueDexPaths(applicationSupport: support, codexHome: codexHome, appBundle: appBundle),
            fileManager: fileManager,
            defaults: defaults
        )
        installer.install()

        #expect(installer.status == .installed)
        #expect(installer.requiresHookTrust)
        #expect(fileManager.isExecutableFile(atPath: installer.paths.helperURL.path))
        #expect(fileManager.fileExists(atPath: codexHome.appending(path: "hooks.json.cuedex-backup").path))
        #expect(try CodexIntegrationInstaller.containsStopHook(
            in: Data(contentsOf: installer.paths.codexHooksURL),
            helperPath: installer.paths.helperURL.path
        ))
        #expect(try String(contentsOf: installer.paths.codexConfigURL, encoding: .utf8) == originalConfig)

        let refreshedInstaller = CodexIntegrationInstaller(
            paths: installer.paths,
            fileManager: fileManager,
            defaults: defaults
        )
        #expect(!refreshedInstaller.requiresHookTrust)
        refreshedInstaller.refreshHelperIfInstalled()
        #expect(!refreshedInstaller.requiresHookTrust)

        installer.uninstall()
        #expect(try !CodexIntegrationInstaller.containsStopHook(
            in: Data(contentsOf: installer.paths.codexHooksURL),
            helperPath: installer.paths.helperURL.path
        ))
        let restoredRoot = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: installer.paths.codexHooksURL)) as? [String: Any]
        )
        let restoredHooks = try #require(restoredRoot["hooks"] as? [String: Any])
        let restoredGroups = try #require(restoredHooks["Stop"] as? [[String: Any]])
        let restoredHandlers = try #require(restoredGroups.first?["hooks"] as? [[String: Any]])
        #expect(restoredHandlers.first?["command"] as? String == "/tmp/existing-hook")
        #expect(try String(contentsOf: installer.paths.codexConfigURL, encoding: .utf8) == originalConfig)
        #expect(installer.status == .notInstalled)
        #expect(!installer.requiresHookTrust)
    }

    @Test @MainActor func legacyNotifierMigratesToStopHook() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let codexHome = root.appending(path: ".codex", directoryHint: .isDirectory)
        let support = root.appending(path: "support", directoryHint: .isDirectory)
        let appBundle = root.appending(path: "CueDex.app", directoryHint: .isDirectory)
        let suiteName = "CueDexMigrationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            try? fileManager.removeItem(at: root)
            defaults.removePersistentDomain(forName: suiteName)
        }

        try fileManager.createDirectory(at: codexHome, withIntermediateDirectories: true)
        let paths = CueDexPaths(applicationSupport: support, codexHome: codexHome, appBundle: appBundle)
        let previousNotifier = "notify = [\"/tmp/existing\"]"
        let legacyConfig = "notify = [\"\(paths.helperURL.path)\"]\nmodel = \"gpt-5.6-sol\"\n"
        try legacyConfig.write(to: paths.codexConfigURL, atomically: true, encoding: .utf8)
        let existingBackup = "original config backup\n"
        let backupURL = codexHome.appending(path: "config.toml.cuedex-backup")
        try existingBackup.write(to: backupURL, atomically: true, encoding: .utf8)
        defaults.set(previousNotifier, forKey: "cuedex.previous-notifier")

        let installer = CodexIntegrationInstaller(paths: paths, fileManager: fileManager, defaults: defaults)
        #expect(installer.status == .installed)
        #expect(!installer.requiresHookTrust)
        installer.refreshHelperIfInstalled()
        #expect(installer.requiresHookTrust)

        #expect(try CodexIntegrationInstaller.containsStopHook(
            in: Data(contentsOf: paths.codexHooksURL),
            helperPath: paths.helperURL.path
        ))
        let migratedConfig = try String(contentsOf: paths.codexConfigURL, encoding: .utf8)
        #expect(migratedConfig.hasPrefix(previousNotifier))
        #expect(!migratedConfig.contains(paths.helperURL.path))
        #expect(try String(contentsOf: backupURL, encoding: .utf8) == existingBackup)
    }
}
