import AVFoundation
import AppKit
import Foundation
import OSLog

@MainActor
final class SpeechController {
    private let logger = Logger(subsystem: "com.peter.CueDex", category: "Speech")
    private let synthesizer: AVSpeechSynthesizer
    private var activeRecording: NSSound?

    init(synthesizer: AVSpeechSynthesizer = AVSpeechSynthesizer()) {
        self.synthesizer = synthesizer
    }

    func play(preferences: CuePreferences) {
        stopActivePlayback()

        switch preferences.speechMode {
        case .prerecorded:
            playRecording(preferences.prerecordedSpeech, volume: preferences.speechVolume)
        case .system:
            speak(
                preferences.speechText,
                voiceIdentifier: preferences.speechVoiceIdentifier,
                volume: preferences.speechVolume
            )
        }
    }

    private func playRecording(_ recording: PrerecordedSpeech, volume: Double) {
        guard let url = Self.prerecordedSpeechURL(for: recording),
              let sound = NSSound(contentsOf: url, byReference: true) else {
            logger.error("Configured pre-recorded speech could not be loaded")
            NSSound.beep()
            return
        }

        sound.volume = Float(min(max(volume, 0), 1))
        activeRecording = sound
        sound.play()
        logger.info("Played configured pre-recorded speech")
    }

    private func speak(_ text: String, voiceIdentifier: String?, volume: Double) {
        let phrase = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else {
            logger.info("Skipped empty speech cue")
            return
        }

        let availableVoiceIdentifier = SpeechVoiceCatalog.voice(withIdentifier: voiceIdentifier)?.id
        let utterance = Self.makeUtterance(
            text: phrase,
            voiceIdentifier: availableVoiceIdentifier,
            volume: volume
        )
        synthesizer.speak(utterance)
        logger.info("Started configured speech cue")
    }

    private func stopActivePlayback() {
        activeRecording?.stop()
        activeRecording = nil
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    static func prerecordedSpeechURL(
        for recording: PrerecordedSpeech,
        bundle: Bundle = .main
    ) -> URL? {
        bundle.url(forResource: recording.resourceName, withExtension: "wav")
    }

    static func makeUtterance(
        text: String,
        voiceIdentifier: String? = nil,
        volume: Double = 1
    ) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.volume = Float(min(max(volume, 0), 1))
        if let voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        } else {
            utterance.voice = nil
        }
        return utterance
    }
}
