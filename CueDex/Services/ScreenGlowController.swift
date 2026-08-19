import AppKit
import OSLog
import QuartzCore

struct GlowPresentation: Sendable {
    let primaryColor: NSColor
    let secondaryColor: NSColor
    let intensity: Double
    let duration: TimeInterval
    let animation: GlowAnimationStyle
}

@MainActor
final class ScreenGlowController {
    private let logger = Logger(subsystem: "com.peter.CueDex", category: "Glow")
    private var overlays: [EdgeGlowPanel] = []
    private var presentationID = UUID()

    func show(_ presentation: GlowPresentation) {
        dismiss()
        presentationID = UUID()
        let activePresentationID = presentationID

        overlays = NSScreen.screens.map { makeOverlay(on: $0, presentation: presentation) }

        logger.info("Presented glow on \(self.overlays.count, privacy: .public) display(s)")

        DispatchQueue.main.asyncAfter(deadline: .now() + presentation.duration + 0.15) { [weak self] in
            guard self?.presentationID == activePresentationID else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        presentationID = UUID()
        overlays.forEach { $0.retire() }
        overlays.removeAll()
    }

    private func makeOverlay(on screen: NSScreen, presentation: GlowPresentation) -> EdgeGlowPanel {
        let contentFrame = CGRect(origin: .zero, size: screen.frame.size)
        let glowView = GlowOverlayView(frame: contentFrame)
        glowView.configure(presentation)

        let panel = EdgeGlowPanel(displayFrame: screen.frame, contentView: glowView)
        panel.present()
        glowView.startAnimation(presentation)
        return panel
    }
}

private final class EdgeGlowPanel: NSPanel {
    init(displayFrame: NSRect, contentView: NSView) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        self.contentView = contentView
        setFrame(displayFrame, display: false)
        backgroundColor = .clear
        isOpaque = false
        ignoresMouseEvents = true
        hasShadow = false
        level = .screenSaver
        animationBehavior = .none
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle
        ]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func present() {
        orderFrontRegardless()
    }

    func retire() {
        orderOut(nil)
        close()
    }
}

private final class GlowOverlayView: NSView {
    private let glowLayer = CALayer()
    private let primaryGlowLayer = CALayer()
    private let secondaryGlowLayer = CALayer()
    private let topGradient = CAGradientLayer()
    private let bottomGradient = CAGradientLayer()
    private let leftGradient = CAGradientLayer()
    private let rightGradient = CAGradientLayer()
    private let borderLayer = CAShapeLayer()
    private let secondaryTopGradient = CAGradientLayer()
    private let secondaryBottomGradient = CAGradientLayer()
    private let secondaryLeftGradient = CAGradientLayer()
    private let secondaryRightGradient = CAGradientLayer()
    private let secondaryBorderLayer = CAShapeLayer()
    private var bandWidth: CGFloat = 72

    private var primaryGradients: [CAGradientLayer] {
        [topGradient, bottomGradient, leftGradient, rightGradient]
    }

    private var secondaryGradients: [CAGradientLayer] {
        [secondaryTopGradient, secondaryBottomGradient, secondaryLeftGradient, secondaryRightGradient]
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.masksToBounds = true
        layer?.addSublayer(glowLayer)
        glowLayer.addSublayer(primaryGlowLayer)
        glowLayer.addSublayer(secondaryGlowLayer)

        primaryGradients.forEach { primaryGlowLayer.addSublayer($0) }
        primaryGlowLayer.addSublayer(borderLayer)
        secondaryGradients.forEach { secondaryGlowLayer.addSublayer($0) }
        secondaryGlowLayer.addSublayer(secondaryBorderLayer)

        configureDirections(
            top: topGradient,
            bottom: bottomGradient,
            left: leftGradient,
            right: rightGradient
        )
        configureDirections(
            top: secondaryTopGradient,
            bottom: secondaryBottomGradient,
            left: secondaryLeftGradient,
            right: secondaryRightGradient
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        glowLayer.frame = bounds
        primaryGlowLayer.frame = bounds
        secondaryGlowLayer.frame = bounds
        layoutEdgeGlow(
            gradients: primaryGradients,
            border: borderLayer
        )
        layoutEdgeGlow(
            gradients: secondaryGradients,
            border: secondaryBorderLayer
        )
    }

    func configure(_ presentation: GlowPresentation) {
        let intensity = min(max(presentation.intensity, 0.2), 1)
        let primaryColor = presentation.primaryColor.usingColorSpace(.deviceRGB) ?? presentation.primaryColor
        let secondaryColor = presentation.secondaryColor.usingColorSpace(.deviceRGB) ?? presentation.secondaryColor

        switch presentation.animation {
        case .breathing:
            configureBreathing(color: primaryColor, intensity: intensity)
        case .alternatingFlash:
            configureAlternatingFlash(primary: primaryColor, secondary: secondaryColor, intensity: intensity)
        }

        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    private func configureBreathing(color: NSColor, intensity: Double) {
        primaryGlowLayer.isHidden = false
        secondaryGlowLayer.isHidden = true
        bandWidth = min(max(min(bounds.width, bounds.height) * 0.085, 54), 116) * (0.72 + 0.28 * intensity)
        configureEdgeGlow(
            gradients: primaryGradients,
            border: borderLayer,
            color: color,
            intensity: intensity
        )
    }

    private func configureAlternatingFlash(primary: NSColor, secondary: NSColor, intensity: Double) {
        primaryGlowLayer.isHidden = false
        secondaryGlowLayer.isHidden = false
        bandWidth = min(max(min(bounds.width, bounds.height) * 0.085, 54), 116) * (0.72 + 0.28 * intensity)
        configureEdgeGlow(
            gradients: primaryGradients,
            border: borderLayer,
            color: primary,
            intensity: intensity
        )
        configureEdgeGlow(
            gradients: secondaryGradients,
            border: secondaryBorderLayer,
            color: secondary,
            intensity: intensity
        )
    }

    func startAnimation(_ presentation: GlowPresentation) {
        switch presentation.animation {
        case .breathing:
            startBreathing(duration: presentation.duration)
        case .alternatingFlash:
            startAlternatingFlash(duration: presentation.duration)
        }
    }

    private func startBreathing(duration: TimeInterval) {
        primaryGlowLayer.opacity = 1
        secondaryGlowLayer.opacity = 0
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.duration = duration
        animation.values = [0, 1, 0.48, 1, 0]
        animation.keyTimes = [0, 0.2, 0.48, 0.78, 1]
        animation.timingFunctions = Array(
            repeating: CAMediaTimingFunction(name: .easeInEaseOut),
            count: 4
        )
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        glowLayer.opacity = 0
        glowLayer.add(animation, forKey: "cuedex.glow.opacity")
    }

    private func startAlternatingFlash(duration: TimeInterval) {
        let envelope = CAKeyframeAnimation(keyPath: "opacity")
        envelope.duration = duration
        envelope.values = [0, 1, 1, 0]
        envelope.keyTimes = [0, 0.1, 0.9, 1]
        envelope.timingFunctions = Array(
            repeating: CAMediaTimingFunction(name: .easeInEaseOut),
            count: 3
        )
        envelope.isRemovedOnCompletion = false
        envelope.fillMode = .forwards
        glowLayer.opacity = 0
        glowLayer.add(envelope, forKey: "cuedex.glow.opacity")

        primaryGlowLayer.opacity = 0
        secondaryGlowLayer.opacity = 0
        primaryGlowLayer.add(
            flashAnimation(values: [0, 1, 0, 1, 0, 0, 0, 0, 0, 0]),
            forKey: "cuedex.flash.primary"
        )
        secondaryGlowLayer.add(
            flashAnimation(values: [0, 0, 0, 0, 0, 0, 1, 0, 1, 0]),
            forKey: "cuedex.flash.secondary"
        )
    }

    private func flashAnimation(values: [NSNumber]) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = values
        animation.keyTimes = [0, 0.08, 0.16, 0.24, 0.32, 0.5, 0.58, 0.66, 0.74, 1]
        animation.duration = 0.95
        animation.repeatCount = .infinity
        animation.timingFunctions = Array(
            repeating: CAMediaTimingFunction(name: .easeInEaseOut),
            count: values.count - 1
        )
        return animation
    }

    private func configureDirections(
        top: CAGradientLayer,
        bottom: CAGradientLayer,
        left: CAGradientLayer,
        right: CAGradientLayer
    ) {
        top.startPoint = CGPoint(x: 0.5, y: 1)
        top.endPoint = CGPoint(x: 0.5, y: 0)
        bottom.startPoint = CGPoint(x: 0.5, y: 0)
        bottom.endPoint = CGPoint(x: 0.5, y: 1)
        left.startPoint = CGPoint(x: 0, y: 0.5)
        left.endPoint = CGPoint(x: 1, y: 0.5)
        right.startPoint = CGPoint(x: 1, y: 0.5)
        right.endPoint = CGPoint(x: 0, y: 0.5)
    }

    private func layoutEdgeGlow(gradients: [CAGradientLayer], border: CAShapeLayer) {
        guard gradients.count == 4 else { return }
        gradients[0].frame = CGRect(x: 0, y: bounds.height - bandWidth, width: bounds.width, height: bandWidth)
        gradients[1].frame = CGRect(x: 0, y: 0, width: bounds.width, height: bandWidth)
        gradients[2].frame = CGRect(x: 0, y: 0, width: bandWidth, height: bounds.height)
        gradients[3].frame = CGRect(x: bounds.width - bandWidth, y: 0, width: bandWidth, height: bounds.height)
        border.frame = bounds
        border.path = CGPath(
            roundedRect: bounds.insetBy(dx: 2, dy: 2),
            cornerWidth: 22,
            cornerHeight: 22,
            transform: nil
        )
    }

    private func configureEdgeGlow(
        gradients: [CAGradientLayer],
        border: CAShapeLayer,
        color: NSColor,
        intensity: Double
    ) {
        let strong = color.withAlphaComponent(0.5 * intensity).cgColor
        let middle = color.withAlphaComponent(0.18 * intensity).cgColor
        let clear = color.withAlphaComponent(0).cgColor

        gradients.forEach {
            $0.colors = [strong, middle, clear]
            $0.locations = [0, 0.42, 1]
        }
        border.fillColor = NSColor.clear.cgColor
        border.strokeColor = color.withAlphaComponent(0.62 * intensity).cgColor
        border.lineWidth = 2.5
        border.shadowColor = color.cgColor
        border.shadowOpacity = Float(0.55 * intensity)
        border.shadowRadius = 18 * intensity
        border.shadowOffset = .zero
    }
}
