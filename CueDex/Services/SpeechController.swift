import AVFoundation
import AppKit
import Foundation
import OSLog

@MainActor
final class SpeechController: NSObject, AVSpeechSynthesizerDelegate, NSSoundDelegate {
    private final class CueUtterance: AVSpeechUtterance {
        nonisolated let playbackID = UUID()
    }

    private let logger = Logger(subsystem: "com.peter.CueDex", category: "Speech")
    private let synthesizer: AVSpeechSynthesizer
    private var activeRecording: NSSound?
    private var activeUtterance: AVSpeechUtterance?
    private var completion: (() -> Void)?

    init(synthesizer: AVSpeechSynthesizer = AVSpeechSynthesizer()) {
        self.synthesizer = synthesizer
        super.init()
        synthesizer.delegate = self
    }

    func play(preferences: CuePreferences, completion: @escaping () -> Void = {}) {
        stop()
        self.completion = completion

        switch preferences.speechMode {
        case .prerecorded:
            playRecording(preferences.prerecordedSpeech)
        case .system:
            speak(
                preferences.speechText,
                voiceIdentifier: preferences.speechVoiceIdentifier
            )
        }
    }

    private func playRecording(_ recording: PrerecordedSpeech) {
        guard let url = Self.prerecordedSpeechURL(for: recording),
              let sound = NSSound(contentsOf: url, byReference: true) else {
            logger.error("Configured pre-recorded speech could not be loaded")
            finish()
            return
        }

        sound.volume = 1
        activeRecording = sound
        sound.delegate = self
        if !sound.play() { finish() }
        logger.info("Played configured pre-recorded speech")
    }

    private func speak(_ text: String, voiceIdentifier: String?) {
        let phrase = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else {
            logger.info("Skipped empty speech cue")
            finish()
            return
        }

        let availableVoiceIdentifier = SpeechVoiceCatalog.voice(withIdentifier: voiceIdentifier)?.id
        let utterance = Self.makeUtterance(
            text: phrase,
            voiceIdentifier: availableVoiceIdentifier
        )
        activeUtterance = utterance
        synthesizer.speak(utterance)
        logger.info("Started configured speech cue")
    }

    func stop() {
        completion = nil
        activeUtterance = nil
        activeRecording?.delegate = nil
        activeRecording?.stop()
        activeRecording = nil
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func finish() {
        let callback = completion
        completion = nil
        activeUtterance = nil
        activeRecording = nil
        callback?()
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        completeSpeech(utterance)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        completeSpeech(utterance)
    }

    private nonisolated func completeSpeech(_ utterance: AVSpeechUtterance) {
        // Transfer only immutable identity, never the non-Sendable utterance.
        guard let playbackID = (utterance as? CueUtterance)?.playbackID else { return }
        Task { @MainActor in
            guard (self.activeUtterance as? CueUtterance)?.playbackID == playbackID else { return }
            self.finish()
        }
    }

    nonisolated func sound(_ sound: NSSound, didFinishPlaying flag: Bool) {
        Task { @MainActor in
            guard self.activeRecording === sound else { return }
            self.finish()
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
        voiceIdentifier: String? = nil
    ) -> AVSpeechUtterance {
        let utterance = CueUtterance(string: text)
        utterance.volume = 1
        if let voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        } else {
            utterance.voice = nil
        }
        return utterance
    }
}
