import AppKit
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class PreferencesStore {
    private static let storageKey = "cuedex.preferences.v2"

    private let defaults: UserDefaults
    private let customSoundStorage: CustomSoundStorage
    private(set) var settings: AppPreferences {
        didSet { persist() }
    }
    var selectedSource = AttentionSource.codex
    @ObservationIgnored var deliveryPolicyDidChange: (() -> Void)?

    var preferences: CuePreferences {
        get { settings[selectedSource] }
        set { settings[selectedSource] = newValue }
    }

    func profile(for source: AttentionSource) -> CuePreferences { settings[source] }

    init(
        defaults: UserDefaults = .standard,
        customSoundStorage: CustomSoundStorage? = nil
    ) {
        self.defaults = defaults
        self.customSoundStorage = customSoundStorage ?? .live()

        if let data = defaults.data(forKey: Self.storageKey),
            let decoded = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            settings = decoded
        } else {
            settings = AppPreferences(legacyData: defaults.data(forKey: "cuedex.preferences.v1"))
        }

        for source in AttentionSource.allCases {
            selectedSource = source
            repairCustomSoundPreference()
        }
        selectedSource = .codex
        persist()
    }

    var appLanguage: AppLanguage {
        get { settings.global.appLanguage }
        set {
            var updated = settings
            let previousLanguage = settings.global.appLanguage
            for source in AttentionSource.allCases {
                if updated[source].speechText == previousLanguage.defaultSpeechText(for: source) {
                    updated[source].speechText = newValue.defaultSpeechText(for: source)
                }
            }
            updated.global.appLanguage = newValue
            settings = updated
        }
    }

    var isPaused: Bool {
        get { settings.global.isPaused }
        set { settings.global.isPaused = newValue; deliveryPolicyDidChange?() }
    }

    var glowEnabled: Bool {
        get { preferences.glowEnabled }
        set { preferences.glowEnabled = newValue }
    }

    var soundEnabled: Bool {
        get { preferences.soundEnabled }
        set { preferences.soundEnabled = newValue }
    }

    var speechEnabled: Bool {
        get { preferences.speechEnabled }
        set { preferences.speechEnabled = newValue }
    }

    var speechMode: SpeechMode {
        get { preferences.speechMode }
        set { preferences.speechMode = newValue }
    }

    var prerecordedSpeech: PrerecordedSpeech {
        get { preferences.prerecordedSpeech }
        set { preferences.prerecordedSpeech = newValue }
    }

    var breathingGlowColor: Color {
        get {
            Color(
                red: preferences.glowRed,
                green: preferences.glowGreen,
                blue: preferences.glowBlue
            )
        }
        set {
            guard let color = NSColor(newValue).usingColorSpace(.deviceRGB) else { return }
            preferences.glowRed = Double(color.redComponent)
            preferences.glowGreen = Double(color.greenComponent)
            preferences.glowBlue = Double(color.blueComponent)
        }
    }

    var flashPrimaryColor: Color {
        get {
            Color(
                red: preferences.glowFlashPrimaryRed,
                green: preferences.glowFlashPrimaryGreen,
                blue: preferences.glowFlashPrimaryBlue
            )
        }
        set {
            guard let color = NSColor(newValue).usingColorSpace(.deviceRGB) else { return }
            preferences.glowFlashPrimaryRed = Double(color.redComponent)
            preferences.glowFlashPrimaryGreen = Double(color.greenComponent)
            preferences.glowFlashPrimaryBlue = Double(color.blueComponent)
        }
    }

    var flashSecondaryColor: Color {
        get {
            Color(
                red: preferences.glowSecondaryRed,
                green: preferences.glowSecondaryGreen,
                blue: preferences.glowSecondaryBlue
            )
        }
        set {
            guard let color = NSColor(newValue).usingColorSpace(.deviceRGB) else { return }
            preferences.glowSecondaryRed = Double(color.redComponent)
            preferences.glowSecondaryGreen = Double(color.greenComponent)
            preferences.glowSecondaryBlue = Double(color.blueComponent)
        }
    }

    var glowAnimation: GlowAnimationStyle {
        get { preferences.glowAnimation }
        set { preferences.glowAnimation = newValue }
    }

    var soundIdentifier: String {
        get { preferences.soundIdentifier }
        set { preferences.soundIdentifier = newValue }
    }

    var customSoundPath: String? {
        preferences.customSoundPath
    }

    var customSoundName: String? {
        preferences.customSoundName
    }

    var speechText: String {
        get { preferences.speechText }
        set { preferences.speechText = newValue }
    }

    var speechVoiceIdentifier: String? {
        get { preferences.speechVoiceIdentifier }
        set { preferences.speechVoiceIdentifier = newValue }
    }

    var quietHoursEnabled: Bool {
        get { settings.global.quietHoursEnabled }
        set { settings.global.quietHoursEnabled = newValue; deliveryPolicyDidChange?() }
    }

    var quietHoursStartMinutes: Int {
        get { settings.global.quietHoursStartMinutes }
        set { settings.global.quietHoursStartMinutes = min(max(newValue, 0), 1439); deliveryPolicyDidChange?() }
    }

    var quietHoursEndMinutes: Int {
        get { settings.global.quietHoursEndMinutes }
        set { settings.global.quietHoursEndMinutes = min(max(newValue, 0), 1439); deliveryPolicyDidChange?() }
    }

    func setCustomSound(_ url: URL) throws {
        let importedURL = try customSoundStorage.importSound(from: url)
        let previousURL = preferences.customSoundPath.map { URL(filePath: $0) }

        var updated = preferences
        updated.customSoundPath = importedURL.path(percentEncoded: false)
        updated.customSoundName = url.deletingPathExtension().lastPathComponent
        updated.soundIdentifier = "custom"
        preferences = updated

        removeUnreferencedSound(at: previousURL)
    }

    func removeCustomSound() {
        let currentURL = preferences.customSoundPath.map { URL(filePath: $0) }
        clearCustomSoundPreference()
        removeUnreferencedSound(at: currentURL)
    }

    func shouldDeliver(at date: Date = .now, calendar: Calendar = .current) -> Bool {
        !settings.global.isPaused && !settings.global.isQuiet(at: date, calendar: calendar)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private func repairCustomSoundPreference() {
        guard let path = preferences.customSoundPath else {
            if preferences.soundIdentifier == "custom" {
                clearCustomSoundPreference()
            }
            return
        }

        let url = URL(filePath: path)
        guard customSoundStorage.fileExists(at: url) else {
            clearCustomSoundPreference()
            return
        }

        guard !customSoundStorage.isManaged(url) else { return }

        do {
            let importedURL = try customSoundStorage.importSound(from: url)
            var updated = preferences
            updated.customSoundPath = importedURL.path(percentEncoded: false)
            updated.customSoundName = updated.customSoundName
                ?? url.deletingPathExtension().lastPathComponent
            preferences = updated
        } catch {
            // Keep a valid legacy path usable if migration fails.
        }
    }

    private func removeUnreferencedSound(at url: URL?) {
        guard let url else { return }
        guard !AttentionSource.allCases.contains(where: { settings[$0].customSoundPath == url.path }) else { return }
        customSoundStorage.removeManagedSound(at: url)
    }

    private func clearCustomSoundPreference() {
        var updated = preferences
        updated.customSoundPath = nil
        updated.customSoundName = nil
        if updated.soundIdentifier == "custom" {
            updated.soundIdentifier = CuePreferences.defaults.soundIdentifier
        }
        preferences = updated
    }
}
