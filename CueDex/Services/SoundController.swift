import AppKit
import OSLog

@MainActor
final class SoundController: NSObject, NSSoundDelegate {
    static let systemSounds = ["Glass", "Ping", "Pop", "Submarine", "Hero", "Funk"]

    private let logger = Logger(subsystem: "com.peter.CueDex", category: "Sound")
    private var activeSound: NSSound?
    private var completion: (() -> Void)?

    func play(preferences: CuePreferences, completion: @escaping () -> Void = {}) {
        stop()

        let sound: NSSound?
        if preferences.soundIdentifier == "custom",
           let path = preferences.customSoundPath {
            sound = NSSound(contentsOf: URL(filePath: path), byReference: true)
        } else {
            sound = NSSound(named: NSSound.Name(preferences.soundIdentifier))?.copy() as? NSSound
        }

        if sound == nil {
            logger.error("Configured sound could not be loaded")
        }
        guard let sound = sound ?? (NSSound(named: NSSound.Name("Glass"))?.copy() as? NSSound) else {
            completion()
            return
        }

        sound.volume = 1 // No app-level attenuation; the system controls output volume.
        activeSound = sound
        self.completion = completion
        sound.delegate = self
        if !sound.play() { finish() }
        logger.info("Played configured cue")
    }

    func stop() {
        completion = nil
        activeSound?.delegate = nil
        activeSound?.stop()
        activeSound = nil
    }

    private func finish() {
        let callback = completion
        completion = nil
        activeSound = nil
        callback?()
    }

    nonisolated func sound(_ sound: NSSound, didFinishPlaying flag: Bool) {
        Task { @MainActor in
            guard self.activeSound === sound else { return }
            self.finish()
        }
    }
}
