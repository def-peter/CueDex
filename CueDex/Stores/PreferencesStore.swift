import AppKit
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class PreferencesStore {
    private static let storageKey = "cuedex.preferences.v1"

    private let defaults: UserDefaults
    private let customSoundStorage: CustomSoundStorage
    private(set) var preferences: CuePreferences {
        didSet { persist() }
    }

    init(
        defaults: UserDefaults = .standard,
        customSoundStorage: CustomSoundStorage? = nil
    ) {
        self.defaults = defaults
        self.customSoundStorage = customSoundStorage ?? .live()

        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(CuePreferences.self, from: data) {
            preferences = decoded
        } else {
            preferences = .defaults
        }

        repairCustomSoundPreference()
    }

    var appLanguage: AppLanguage {
        get { preferences.appLanguage }
        set {
            var updated = preferences
            let usesDefaultSpeechText = updated.speechText == updated.appLanguage.defaultSpeechText
            updated.appLanguage = newValue
            if usesDefaultSpeechText {
                updated.speechText = newValue.defaultSpeechText
            }
            preferences = updated
        }
    }

    var isPaused: Bool {
        get { preferences.isPaused }
        set { preferences.isPaused = newValue }
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

    var glowIntensity: Double {
        get { preferences.glowIntensity }
        set { preferences.glowIntensity = min(max(newValue, 0.2), 1) }
    }

    var glowDuration: Double {
        get { preferences.glowDuration }
        set { preferences.glowDuration = min(max(newValue, 0.8), 5) }
    }

    var glowAnimation: GlowAnimationStyle {
        get { preferences.glowAnimation }
        set { preferences.glowAnimation = newValue }
    }

    var soundIdentifier: String {
        get { preferences.soundIdentifier }
        set { preferences.soundIdentifier = newValue }
    }

    var soundVolume: Double {
        get { preferences.soundVolume }
        set { preferences.soundVolume = min(max(newValue, 0), 1) }
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
        get { preferences.quietHoursEnabled }
        set { preferences.quietHoursEnabled = newValue }
    }

    var quietHoursStartMinutes: Int {
        get { preferences.quietHoursStartMinutes }
        set { preferences.quietHoursStartMinutes = min(max(newValue, 0), 1439) }
    }

    var quietHoursEndMinutes: Int {
        get { preferences.quietHoursEndMinutes }
        set { preferences.quietHoursEndMinutes = min(max(newValue, 0), 1439) }
    }

    func setCustomSound(_ url: URL) throws {
        let importedURL = try customSoundStorage.importSound(from: url)
        let previousURL = preferences.customSoundPath.map { URL(filePath: $0) }

        var updated = preferences
        updated.customSoundPath = importedURL.path(percentEncoded: false)
        updated.customSoundName = url.deletingPathExtension().lastPathComponent
        updated.soundIdentifier = "custom"
        preferences = updated

        customSoundStorage.removeManagedSound(at: previousURL)
    }

    func removeCustomSound() {
        let currentURL = preferences.customSoundPath.map { URL(filePath: $0) }
        customSoundStorage.removeManagedSound(at: currentURL)
        clearCustomSoundPreference()
    }

    func shouldDeliver(at date: Date = .now, calendar: Calendar = .current) -> Bool {
        !preferences.isPaused && !preferences.isQuiet(at: date, calendar: calendar)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
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
