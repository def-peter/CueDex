import AppKit
import Foundation
import OSLog

struct BundledSoundOption: Identifiable, Equatable {
    let id: String
    let titleKey: String
    let resourceName: String
    let fileExtension: String
}

@MainActor
final class SoundController {
    static let systemSounds = ["Glass", "Ping", "Pop", "Submarine", "Hero", "Funk"]
    static let bundledSounds = [
        BundledSoundOption(
            id: "bundled.message-reminder-male",
            titleKey: "Message Reminder (Male Voice)",
            resourceName: "message-reminder-male",
            fileExtension: "wav"
        ),
        BundledSoundOption(
            id: "bundled.message-reminder-female",
            titleKey: "Message Reminder (Female Voice)",
            resourceName: "message-reminder-female",
            fileExtension: "wav"
        ),
    ]

    private let logger = Logger(subsystem: "com.peter.CueDex", category: "Sound")
    private var activeSound: NSSound?

    func play(preferences: CuePreferences) {
        activeSound?.stop()

        let sound: NSSound?
        if preferences.soundIdentifier == "custom",
           let path = preferences.customSoundPath {
            sound = NSSound(contentsOf: URL(filePath: path), byReference: true)
        } else if let url = Self.bundledSoundURL(for: preferences.soundIdentifier) {
            sound = NSSound(contentsOf: url, byReference: true)
        } else {
            sound = NSSound(named: NSSound.Name(preferences.soundIdentifier))
        }

        guard let sound else {
            logger.error("Configured sound could not be loaded")
            NSSound.beep()
            return
        }

        sound.volume = Float(preferences.soundVolume)
        activeSound = sound
        sound.play()
        logger.info("Played configured cue")
    }

    static func bundledSoundURL(for identifier: String, bundle: Bundle = .main) -> URL? {
        guard let option = bundledSounds.first(where: { $0.id == identifier }) else { return nil }
        return bundle.url(forResource: option.resourceName, withExtension: option.fileExtension)
    }
}
