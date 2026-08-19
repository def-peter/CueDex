import AVFoundation
import Foundation
import OSLog

@MainActor
final class SpeechController {
    private let logger = Logger(subsystem: "com.peter.CueDex", category: "Speech")
    private let synthesizer: AVSpeechSynthesizer

    init(synthesizer: AVSpeechSynthesizer = AVSpeechSynthesizer()) {
        self.synthesizer = synthesizer
    }

    func speak(_ text: String, voiceIdentifier: String?) {
        let phrase = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else {
            logger.info("Skipped empty speech cue")
            return
        }

        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let availableVoiceIdentifier = SpeechVoiceCatalog.voice(withIdentifier: voiceIdentifier)?.id
        let utterance = Self.makeUtterance(text: phrase, voiceIdentifier: availableVoiceIdentifier)
        synthesizer.speak(utterance)
        logger.info("Started configured speech cue")
    }

    static func makeUtterance(
        text: String,
        voiceIdentifier: String? = nil
    ) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        if let voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        } else {
            utterance.voice = nil
        }
        return utterance
    }
}
