import AppKit
import OSLog

@MainActor
final class SoundController {
    static let systemSounds = ["Glass", "Ping", "Pop", "Submarine", "Hero", "Funk"]

    private let logger = Logger(subsystem: "com.peter.CueDex", category: "Sound")
    private var activeSound: NSSound?

    func play(preferences: CuePreferences) {
        activeSound?.stop()

        let sound: NSSound?
        if preferences.soundIdentifier == "custom",
           let path = preferences.customSoundPath {
            sound = NSSound(contentsOf: URL(filePath: path), byReference: true)
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
}
