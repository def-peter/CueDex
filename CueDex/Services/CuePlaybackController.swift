import AppKit

@MainActor
protocol CuePlaying: AnyObject {
    func play(_ profile: CuePreferences, preview: CuePlaybackController.Preview, completion: @escaping () -> Void)
    func stop()
}

@MainActor
final class CuePlaybackController: CuePlaying {
    enum Preview { case all, glow, sound, speech }

    private let glow = ScreenGlowController()
    private let sound = SoundController()
    private let speech = SpeechController()
    private var generation = UUID()
    private var remaining = 0
    private var completion: (() -> Void)?

    func play(_ profile: CuePreferences, preview: Preview = .all, completion: @escaping () -> Void) {
        stop()
        let token = generation
        let useGlow = profile.glowEnabled && (preview == .all || preview == .glow)
        let useSound = profile.soundEnabled && (preview == .all || preview == .sound)
        let useSpeech = profile.speechEnabled && (preview == .all || preview == .speech)
        remaining = [useGlow, useSound, useSpeech].filter { $0 }.count
        self.completion = completion
        guard remaining > 0 else { self.completion = nil; completion(); return }
        if useGlow { glow.show(Self.presentation(profile)) { [weak self] in self?.finish(token) } }
        if useSound { sound.play(preferences: profile) { [weak self] in self?.finish(token) } }
        if useSpeech { speech.play(preferences: profile) { [weak self] in self?.finish(token) } }
    }

    func stop() {
        generation = UUID()
        remaining = 0
        completion = nil
        glow.dismiss()
        sound.stop()
        speech.stop()
    }

    private func finish(_ token: UUID) {
        guard token == generation else { return }
        remaining -= 1
        guard remaining <= 0 else { return }
        let callback = completion
        completion = nil
        callback?()
    }

    static func presentation(_ profile: CuePreferences) -> GlowPresentation {
        let primary: NSColor
        switch profile.glowAnimation {
        case .breathing:
            primary = NSColor(red: profile.glowRed, green: profile.glowGreen, blue: profile.glowBlue, alpha: 1)
        case .alternatingFlash:
            primary = NSColor(red: profile.glowFlashPrimaryRed, green: profile.glowFlashPrimaryGreen, blue: profile.glowFlashPrimaryBlue, alpha: 1)
        }
        return GlowPresentation(
            primaryColor: primary,
            secondaryColor: NSColor(red: profile.glowSecondaryRed, green: profile.glowSecondaryGreen, blue: profile.glowSecondaryBlue, alpha: 1),
            animation: profile.glowAnimation
        )
    }
}
