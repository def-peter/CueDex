import AppKit
import Foundation
import Testing
@testable import CueDex

struct MultiSourceTests {
    @Test func openCodeBridgeResourceIsBundled() throws {
        let resource = try #require(Bundle.main.url(forResource: "cuedex-opencode", withExtension: "js"))
        let script = try String(contentsOf: resource, encoding: .utf8)
        #expect(script.hasPrefix("// CueDex managed OpenCode V2 bridge."))
        #expect(script.contains("session.execution.succeeded"))
    }

    private func event(_ source: AttentionSource = .codex, id: String, at date: Date) -> CueEvent {
        CueEvent(source: source, eventID: id, sessionID: "session", completedAt: date)
    }

    @Test @MainActor func legacySettingsMigrateToCodexAndGlobalOnly() throws {
        let name = "CueDexMigration.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(Data(#"{"appLanguage":"en","isPaused":true,"quietHoursEnabled":true,"quietHoursStartMinutes":600,"quietHoursEndMinutes":900,"glowRed":0.91,"soundIdentifier":"Ping","soundVolume":0.13,"speechText":"My own phrase"}"#.utf8), forKey: "cuedex.preferences.v1")
        let store = PreferencesStore(defaults: defaults)
        #expect(store.appLanguage == .english)
        #expect(store.isPaused && store.quietHoursEnabled)
        #expect(store.quietHoursStartMinutes == 600 && store.quietHoursEndMinutes == 900)
        #expect(store.profile(for: .codex).glowRed == 0.91)
        #expect(store.profile(for: .codex).soundIdentifier == "Ping")
        #expect(store.profile(for: .codex).speechText == "My own phrase")
        #expect(store.profile(for: .opencode).soundIdentifier == "Glass")
        #expect(store.profile(for: .opencode).speechText == "OpenCode has finished responding.")
        #expect(defaults.data(forKey: "cuedex.preferences.v1") != nil)
        let data = try #require(defaults.data(forKey: "cuedex.preferences.v2"))
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let codex = try #require(root["codex"] as? [String: Any])
        #expect(codex["appLanguage"] == nil && codex["quietHoursEnabled"] == nil)
    }

    @Test @MainActor func sourceProfilesPersistIndependentlyAndNeverRerunLegacyMigration() throws {
        let name = "CueDexProfiles.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = PreferencesStore(defaults: defaults)
        store.soundIdentifier = "Ping"
        store.speechText = "Codex custom cue"
        store.selectedSource = .opencode
        store.soundIdentifier = "Hero"
        store.speechText = "OpenCode custom cue"
        store.glowEnabled = false
        store.speechEnabled = true
        defaults.set(Data(#"{"soundIdentifier":"Pop"}"#.utf8), forKey: "cuedex.preferences.v1")
        let restored = PreferencesStore(defaults: defaults)
        #expect(restored.profile(for: .codex).soundIdentifier == "Ping")
        #expect(restored.profile(for: .codex).speechText == "Codex custom cue")
        #expect(restored.profile(for: .codex).glowEnabled)
        #expect(restored.profile(for: .opencode).soundIdentifier == "Hero")
        #expect(restored.profile(for: .opencode).speechText == "OpenCode custom cue")
        #expect(!restored.profile(for: .opencode).glowEnabled)
        #expect(restored.profile(for: .opencode).speechEnabled)
    }

    @Test @MainActor func globalLanguageUpdatesOnlyEachSourcesDefaultText() throws {
        let name = "CueDexSourceLanguage.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = PreferencesStore(defaults: defaults)
        store.appLanguage = .english
        #expect(store.profile(for: .codex).speechText == "Codex has finished responding.")
        #expect(store.profile(for: .opencode).speechText == "OpenCode has finished responding.")
        store.selectedSource = .opencode
        // This happens to equal a different source's default and is still custom.
        store.speechText = "Codex has finished responding."
        store.appLanguage = .simplifiedChinese
        let restored = PreferencesStore(defaults: defaults)
        #expect(restored.profile(for: .codex).speechText == "Codex 已回复完成。")
        #expect(restored.profile(for: .opencode).speechText == "Codex has finished responding.")
    }

    @Test @MainActor func missingProfilesGainSourceCorrectDefaults() throws {
        let data = Data(#"{"global":{"appLanguage":"en"},"codex":{},"opencode":{}}"#.utf8)
        let settings = try JSONDecoder().decode(AppPreferences.self, from: data)
        #expect(settings.codex.speechText == "Codex has finished responding.")
        #expect(settings.opencode.speechText == "OpenCode has finished responding.")
    }

    @Test @MainActor func pauseIsGlobalAndDoesNotChangeWhenSelectingAnotherSource() throws {
        let name = "CueDexGlobal.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = PreferencesStore(defaults: defaults)
        store.isPaused = true
        store.selectedSource = .opencode
        #expect(store.isPaused)
        #expect(!store.shouldDeliver())
    }

    @Test @MainActor func legacyGlowSettingsAndAudioVolumesAreDiscarded() throws {
        let data = Data(#"{"glowIntensity":0.86,"glowDuration":3.8,"soundVolume":0.12,"speechVolume":0.23,"soundIdentifier":"Ping","speechText":"Custom cue"}"#.utf8)
        let settings = AppPreferences(legacyData: data)
        let presentation = CuePlaybackController.presentation(settings.codex)
        #expect(presentation.intensity == 1 && presentation.duration == 3)
        #expect(settings.codex.soundIdentifier == "Ping")
        #expect(settings.codex.speechText == "Custom cue")
        let root = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
        for key in ["global", "codex", "opencode"] {
            let profile = try #require(root[key] as? [String: Any])
            #expect(profile["glowIntensity"] == nil && profile["glowDuration"] == nil)
            #expect(profile["soundVolume"] == nil && profile["speechVolume"] == nil)
        }
    }

    @Test @MainActor func oldPerSourceGlowSettingsAreRemovedOnSave() throws {
        let name = "CueDexFixedGlow.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let data = Data(#"{"global":{"appLanguage":"en"},"codex":{"glowIntensity":0.44,"glowDuration":3.6,"soundVolume":0.1},"opencode":{"glowIntensity":0.96,"glowDuration":1.2,"speechVolume":0.2}}"#.utf8)
        defaults.set(data, forKey: "cuedex.preferences.v2")
        let store = PreferencesStore(defaults: defaults)
        store.speechText = "Preserved custom cue"
        let restored = PreferencesStore(defaults: defaults)
        #expect(restored.appLanguage == .english)
        #expect(restored.speechText == "Preserved custom cue")
        for source in AttentionSource.allCases {
            let presentation = CuePlaybackController.presentation(restored.profile(for: source))
            #expect(presentation.intensity == 1 && presentation.duration == 3)
        }
        let persisted = try #require(defaults.data(forKey: "cuedex.preferences.v2"))
        let root = try #require(JSONSerialization.jsonObject(with: persisted) as? [String: Any])
        for key in ["global", "codex", "opencode"] {
            let section = try #require(root[key] as? [String: Any])
            #expect(section["glowIntensity"] == nil && section["glowDuration"] == nil)
        }
    }

    @Test @MainActor func oldGlobalGlowSettingsCannotOverrideFixedPlayback() throws {
        let data = Data(#"{"global":{"glowIntensity":0.62,"glowDuration":4.6},"codex":{"glowIntensity":0.9,"glowDuration":3.2},"opencode":{"glowDuration":4.8}}"#.utf8)
        let settings = try JSONDecoder().decode(AppPreferences.self, from: data)
        for source in AttentionSource.allCases {
            let presentation = CuePlaybackController.presentation(settings[source])
            #expect(presentation.intensity == 1 && presentation.duration == 3)
        }
        let encoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
        let global = try #require(encoded["global"] as? [String: Any])
        #expect(global["glowIntensity"] == nil && global["glowDuration"] == nil)
    }

    @Test @MainActor func obsoleteGlowFieldsDoNotAffectPreferenceDecoding() throws {
        let data = Data(#"{"global":{"glowIntensity":"obsolete","glowDuration":-2},"codex":{"glowIntensity":9,"glowDuration":-2,"glowRed":0.91}}"#.utf8)
        let settings = try JSONDecoder().decode(AppPreferences.self, from: data)
        #expect(settings.codex.glowRed == 0.91)
        let presentation = CuePlaybackController.presentation(settings.codex)
        #expect(presentation.intensity == 1 && presentation.duration == 3)
    }

    @Test @MainActor func removingSharedManagedSoundPreservesTheOtherProfile() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appending(path: UUID().uuidString)
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }
        let sound = root.appending(path: "shared.wav")
        try Data("fixture".utf8).write(to: sound)
        let name = "CueDexSharedSound.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        var settings = AppPreferences()
        for source in AttentionSource.allCases {
            settings[source].customSoundPath = sound.path
            settings[source].soundIdentifier = "custom"
        }
        defaults.set(try JSONEncoder().encode(settings), forKey: "cuedex.preferences.v2")
        let store = PreferencesStore(defaults: defaults, customSoundStorage: CustomSoundStorage(directory: root))
        store.removeCustomSound()
        #expect(manager.fileExists(atPath: sound.path))
        #expect(store.profile(for: .opencode).customSoundPath == sound.path)
        store.selectedSource = .opencode
        store.removeCustomSound()
        #expect(!manager.fileExists(atPath: sound.path))
    }

    @Test func queueCoalescesPerSourceWithoutMergingSources() throws {
        let now = Date()
        var queue = CueEventQueue()
        queue.receive(event(id: "one", at: now), deliver: true, now: now)
        queue.receive(event(.opencode, id: "same", at: now), deliver: true, now: now)
        queue.receive(event(id: "two", at: now), deliver: true, now: now)
        #expect(queue.pending.count == 2)
        #expect(queue.next(now: now)?.eventID == "two")
        #expect(queue.next(now: now)?.source == .opencode)
        #expect(queue.next(now: now) == nil)
    }

    @Test @MainActor func deduplicationSurvivesInterleavedSessionsAndSuppression() {
        let now = Date()
        var queue = CueEventQueue()
        let a = event(id: "a", at: now)
        let b = CueEvent(source: .codex, eventID: "b", sessionID: "other", completedAt: now)
        let first = queue.receive(a, deliver: false, now: now)
        let second = queue.receive(b, deliver: true, now: now)
        let duplicate = queue.receive(a, deliver: true, now: now)
        #expect(first && second && !duplicate)
        #expect(queue.pending == [b])
        let otherSource = queue.receive(event(.opencode, id: "a", at: now), deliver: true, now: now)
        #expect(otherSource)
        #expect(queue.pending.count == 2)
    }

    @Test func delayedOlderEventsNeverReplaceTheNewestPendingCue() {
        let now = Date()
        var queue = CueEventQueue()
        queue.receive(event(id: "newest", at: now), deliver: true, now: now)
        queue.receive(event(id: "older", at: now.addingTimeInterval(-1)), deliver: true, now: now)
        #expect(queue.pending.map(\.eventID) == ["newest"])
    }

    @Test func expiredFutureAndWaitingEventsDoNotPlay() {
        let now = Date()
        var queue = CueEventQueue()
        let old = queue.receive(event(id: "old", at: now.addingTimeInterval(-60)), deliver: true, now: now)
        let future = queue.receive(event(id: "future", at: now.addingTimeInterval(1)), deliver: true, now: now)
        #expect(!old && !future)
        queue.receive(event(id: "waiting", at: now), deliver: true, now: now)
        #expect(queue.next(now: now.addingTimeInterval(60)) == nil)
    }

    @Test func disablingOneSourceOnlyClearsItsPendingEvents() {
        let now = Date()
        var queue = CueEventQueue()
        queue.receive(event(id: "a", at: now), deliver: true, now: now)
        queue.receive(event(.opencode, id: "b", at: now), deliver: true, now: now)
        queue.remove(source: .opencode)
        #expect(queue.pending.map(\.source) == [.codex])
        queue.clear()
        #expect(queue.pending.isEmpty)
    }

    @Test func bridgeEventsDecodeSecondsAndRejectUnknownSources() throws {
        let data = Data(#"{"source":"opencode","eventID":"evt_1","sessionID":"ses_1","completedAt":2000}"#.utf8)
        let decoded = try CueEvent.decode(data)
        #expect(decoded.source == .opencode)
        #expect(decoded.completedAt == Date(timeIntervalSince1970: 2000))
        #expect(throws: (any Error).self) {
            try CueEvent.decode(Data(#"{"source":"unknown","eventID":"1","sessionID":"s","completedAt":2000}"#.utf8))
        }
    }

    @Test @MainActor func routingUsesEventSourceNotTheSelectedSettingsSource() throws {
        try withModel { model, player in
            model.preferences.soundIdentifier = "Ping"
            model.preferences.selectedSource = .opencode
            model.preferences.soundIdentifier = "Hero"
            model.handleCompletion(event(id: "codex-1", at: .now))
            #expect(player.profiles.map(\.soundIdentifier) == ["Ping"])
            model.handleCompletion(event(.opencode, id: "open-1", at: .now))
            model.handleCompletion(event(.opencode, id: "open-2", at: .now))
            #expect(player.profiles.count == 1)
            player.finish()
            #expect(player.profiles.map(\.soundIdentifier) == ["Ping", "Hero"])
            player.finish()
            #expect(!model.isPlayingCue)
        }
    }

    @Test @MainActor func pausingStopsPlaybackAndClearsWaitingWithoutReplaying() throws {
        try withModel { model, player in
            model.handleCompletion(event(id: "first", at: .now))
            model.handleCompletion(event(.opencode, id: "waiting", at: .now))
            #expect(model.isPlayingCue)
            model.preferences.isPaused = true
            #expect(!model.isPlayingCue)
            #expect(player.stops == 1)
            model.preferences.isPaused = false
            model.handleCompletion(event(.opencode, id: "waiting", at: .now))
            #expect(player.profiles.count == 1)
        }
    }

    @Test @MainActor func previewsNeverVerifyAnIntegration() throws {
        try withModel { model, player in
            #expect(model.lastReceived.isEmpty)
            model.preferences.isPaused = true
            model.testCue(source: .opencode)
            #expect(player.profiles.count == 1)
            #expect(model.lastReceived.isEmpty)
            player.finish()
        }
    }

    @Test @MainActor func previewsAndRealCuesUseFixedGlowForBothSources() throws {
        try withModel { model, player in
            for source in AttentionSource.allCases {
                model.preferences.selectedSource = source
                model.testGlow()
                player.finish()
                model.handleCompletion(event(source, id: source.rawValue, at: .now))
                player.finish()
            }
            #expect(player.profiles.count == 4)
            for profile in player.profiles {
                let presentation = CuePlaybackController.presentation(profile)
                #expect(presentation.intensity == 1 && presentation.duration == 3)
            }
        }
    }

    @Test @MainActor func fixedGlowPreservesSelectedColorsAndAnimation() {
        var profile = CuePreferences()
        profile.glowRed = 0.91
        profile.glowGreen = 0.32
        profile.glowBlue = 0.17
        profile.glowFlashPrimaryRed = 0.26
        profile.glowFlashPrimaryGreen = 0.63
        profile.glowFlashPrimaryBlue = 0.84
        profile.glowSecondaryRed = 0.72
        profile.glowSecondaryGreen = 0.54
        profile.glowSecondaryBlue = 0.38
        for animation in GlowAnimationStyle.allCases {
            profile.glowAnimation = animation
            let presentation = CuePlaybackController.presentation(profile)
            #expect(presentation.animation == animation)
            #expect(presentation.intensity == 1 && presentation.duration == 3)
            #expect(presentation.primaryColor.redComponent == (animation == .breathing ? 0.91 : 0.26))
            #expect(presentation.primaryColor.greenComponent == (animation == .breathing ? 0.32 : 0.63))
            #expect(presentation.primaryColor.blueComponent == (animation == .breathing ? 0.17 : 0.84))
            #expect(presentation.primaryColor.alphaComponent == 1)
            #expect(presentation.secondaryColor.redComponent == 0.72)
            #expect(presentation.secondaryColor.greenComponent == 0.54)
            #expect(presentation.secondaryColor.blueComponent == 0.38)
        }
    }

    @Test @MainActor func unseenDelayedEventsFromBeforeResumeAreNotReplayed() throws {
        try withModel { model, player in
            let delayed = event(id: "unseen", at: .now.addingTimeInterval(-1))
            model.preferences.isPaused = true
            model.preferences.isPaused = false
            model.handleCompletion(delayed)
            #expect(player.profiles.isEmpty)
            model.handleCompletion(event(id: "new", at: .now))
            #expect(player.profiles.count == 1)
            player.finish()
        }
    }

    @Test @MainActor func enteringQuietHoursStopsPlaybackAndDiscardsTheQueue() throws {
        try withModel { model, player in
            model.handleCompletion(event(id: "active", at: .now))
            model.handleCompletion(event(.opencode, id: "waiting", at: .now))
            model.preferences.quietHoursStartMinutes = 0
            model.preferences.quietHoursEndMinutes = 0
            model.preferences.quietHoursEnabled = true
            #expect(!model.isPlayingCue)
            #expect(player.stops == 1)
            model.preferences.quietHoursEnabled = false
            #expect(player.profiles.count == 1)
        }
    }

    @Test @MainActor func disablingTheActiveSourceContinuesTheOtherSourcesQueue() throws {
        try withModel { model, player in
            model.preferences.soundIdentifier = "Ping"
            model.preferences.selectedSource = .opencode
            model.preferences.soundIdentifier = "Hero"
            model.handleCompletion(event(id: "active", at: .now))
            model.handleCompletion(event(.opencode, id: "waiting", at: .now))
            model.disableIntegration(.codex)
            #expect(!model.integration.isInstalled)
            #expect(model.opencodeIntegration.isInstalled)
            #expect(player.profiles.map(\.soundIdentifier) == ["Ping", "Hero"])
            #expect(player.stops == 1)
            #expect(model.preferences.profile(for: .codex).soundIdentifier == "Ping")
            player.finish()
        }
    }

    @Test @MainActor func monitorPreservesBothSourcesInOneFilesystemBatch() async throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appending(path: UUID().uuidString)
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        for source in AttentionSource.allCases {
            let value = event(source, id: source.rawValue, at: .now.addingTimeInterval(-1))
            try encoder.encode(value).write(to: root.appending(path: "cue-\(source.rawValue).json"))
        }
        var received: [CueEvent] = []
        let monitor = CueEventMonitor(eventsDirectory: root)
        try monitor.start { received.append($0) }
        for _ in 0..<100 {
            if received.count == 2 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(Set(received.map(\.source)) == Set(AttentionSource.allCases))
        withExtendedLifetime(monitor) {}
    }

    @MainActor private func withModel(_ body: (AppModel, RecordingPlayer) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let name = "CueDexRouting.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: name)
        }
        let paths = CueDexPaths(applicationSupport: root.appending(path: "support"), codexHome: root.appending(path: "codex"), appBundle: root, opencodeConfigurationDirectory: root.appending(path: "opencode"))
        let player = RecordingPlayer()
        let model = AppModel(paths: paths, defaults: defaults, runtimeServicesEnabled: false, playback: player)
        model.integration.install()
        try FileManager.default.createDirectory(at: paths.opencodePluginURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "// CueDex managed OpenCode V2 bridge.".write(to: paths.opencodePluginURL, atomically: true, encoding: .utf8)
        try "fixture".write(to: paths.opencodeGateURL, atomically: true, encoding: .utf8)
        model.opencodeIntegration.refresh()
        try body(model, player)
    }

    @Test @MainActor func openCodeInstallerManagesOnlyItsOwnFile() async throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? manager.removeItem(at: root) }
        let paths = CueDexPaths(
            applicationSupport: root.appending(path: "Support with spaces"),
            codexHome: root.appending(path: "codex"), appBundle: root.appending(path: "CueDex.app"),
            opencodeConfigurationDirectory: root.appending(path: "opencode")
        )
        let directory = paths.opencodePluginURL.deletingLastPathComponent()
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let other = directory.appending(path: "other.js")
        try "other plugin".write(to: other, atomically: true, encoding: .utf8)
        let template = "// CueDex managed OpenCode V2 bridge.\nconst gate = \"__CUEDEX_GATE__\"; const generation = \"__CUEDEX_GENERATION__\";"
        let installer = OpenCodeIntegrationInstaller(paths: paths, versionProvider: { "2.1.1" }, pluginTemplate: { template })
        await installer.install()
        #expect(installer.isInstalled)
        #expect(installer.lastError == nil)
        let installed = try String(contentsOf: paths.opencodePluginURL, encoding: .utf8)
        #expect(!installed.contains("__CUEDEX_"))
        #expect(installed.contains("Support with spaces"))
        #expect(manager.fileExists(atPath: paths.opencodeGateURL.path))
        installer.uninstall()
        #expect(!installer.isInstalled)
        #expect(!manager.fileExists(atPath: paths.opencodeGateURL.path))
        #expect(try String(contentsOf: other, encoding: .utf8) == "other plugin")
    }

    @Test @MainActor func openCodeReinstallUpdatesWakeTargetAndInvalidatesOldGeneration() async throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? manager.removeItem(at: root) }
        let support = root.appending(path: "Support with spaces")
        let configuration = root.appending(path: "opencode")
        let debugPaths = CueDexPaths(
            applicationSupport: support, codexHome: root.appending(path: "codex"),
            appBundle: root.appending(path: "Debug/CueDex.app"),
            opencodeConfigurationDirectory: configuration
        )
        let otherPlugin = configuration.appending(path: "plugins/other.js")
        try manager.createDirectory(at: otherPlugin.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "user plugin".write(to: otherPlugin, atomically: true, encoding: .utf8)
        let debugInstaller = OpenCodeIntegrationInstaller(paths: debugPaths, versionProvider: { "2.1.1" })
        await debugInstaller.install()
        #expect(debugInstaller.isInstalled)
        let oldGeneration = try String(contentsOf: debugPaths.opencodeGateURL, encoding: .utf8)

        let releasePaths = CueDexPaths(
            applicationSupport: support, codexHome: debugPaths.codexHome,
            appBundle: root.appending(path: "Applications/CueDex.app"),
            opencodeConfigurationDirectory: configuration
        )
        let releaseInstaller = OpenCodeIntegrationInstaller(paths: releasePaths, versionProvider: { "2.1.1" })
        await releaseInstaller.install()
        #expect(releaseInstaller.isInstalled)
        #expect(releaseInstaller.lastError == nil)
        let generation = try String(contentsOf: releasePaths.opencodeGateURL, encoding: .utf8)
        #expect(generation != oldGeneration)
        let templateURL = try #require(Bundle.main.url(forResource: "cuedex-opencode", withExtension: "js"))
        let template = try String(contentsOf: templateURL, encoding: .utf8)
        #expect(
            try String(contentsOf: releasePaths.opencodePluginURL, encoding: .utf8)
                == OpenCodeIntegrationInstaller.render(template, paths: releasePaths, generation: generation)
        )
        #expect(try String(contentsOf: otherPlugin, encoding: .utf8) == "user plugin")
    }

    @Test @MainActor func openCodeInstallerRejectsUnsupportedVersionsAndForeignFiles() async throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? manager.removeItem(at: root) }
        let paths = CueDexPaths(applicationSupport: root.appending(path: "support"), codexHome: root.appending(path: "codex"), appBundle: root, opencodeConfigurationDirectory: root.appending(path: "opencode"))
        let unsupported = OpenCodeIntegrationInstaller(paths: paths, versionProvider: { "1.0.0" })
        await unsupported.install()
        #expect(!manager.fileExists(atPath: paths.opencodePluginURL.path))
        #expect(unsupported.lastError != nil)
        try manager.createDirectory(at: paths.opencodePluginURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "user-owned".write(to: paths.opencodePluginURL, atomically: true, encoding: .utf8)
        let installer = OpenCodeIntegrationInstaller(paths: paths, versionProvider: { "2.1.1" }, pluginTemplate: { "unused" })
        await installer.install()
        #expect(installer.lastError != nil)
        installer.uninstall()
        #expect(try String(contentsOf: paths.opencodePluginURL, encoding: .utf8) == "user-owned")
    }
}

@MainActor
private final class RecordingPlayer: CuePlaying {
    var profiles: [CuePreferences] = []
    var stops = 0
    private var completion: (() -> Void)?

    func play(_ profile: CuePreferences, preview: CuePlaybackController.Preview, completion: @escaping () -> Void) {
        profiles.append(profile)
        self.completion = completion
    }
    func stop() { stops += 1; completion = nil }
    func finish() {
        let callback = completion
        completion = nil
        callback?()
    }
}
