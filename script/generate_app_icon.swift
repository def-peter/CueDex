import AppKit

let outputDirectory = URL(filePath: CommandLine.arguments.dropFirst().first ?? ".", directoryHint: .isDirectory)

let outputs: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(deviceRed: red, green: green, blue: blue, alpha: alpha)
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let scale = size / 1024
    NSGraphicsContext.current?.imageInterpolation = .high

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }

    let canvasTransform = NSAffineTransform()
    canvasTransform.translateX(by: 0, yBy: size)
    canvasTransform.scaleX(by: scale, yBy: -scale)
    canvasTransform.concat()

    let tile = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 202, yRadius: 202)
    color(0.961, 0.969, 0.980).setFill()
    tile.fill()
    color(0.882, 0.902, 0.929).setStroke()
    tile.lineWidth = 2
    tile.stroke()

    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    let glowIntensity: CGFloat = 1.00
    let iconGlowGain: CGFloat = 1.80
    let rawBandWidth = min(max(896 * 0.085, 54), 116)
    let bandWidth = min(rawBandWidth * (0.72 + 0.28 * glowIntensity) * iconGlowGain, 144)
    let glowColor = color(0.239, 0.580, 1.0)
    let gradientColors = [
        glowColor.withAlphaComponent(min(0.5 * glowIntensity * iconGlowGain, 1)).cgColor,
        glowColor.withAlphaComponent(min(0.18 * glowIntensity * iconGlowGain, 1)).cgColor,
        glowColor.withAlphaComponent(0).cgColor
    ] as CFArray
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: gradientColors,
        locations: [0, 0.42, 1]
    )!
    let context = NSGraphicsContext.current!.cgContext
    let edges: [(rect: CGRect, start: CGPoint, end: CGPoint)] = [
        (CGRect(x: 266, y: 64, width: 492, height: bandWidth), CGPoint(x: 512, y: 64), CGPoint(x: 512, y: 64 + bandWidth)),
        (CGRect(x: 266, y: 960 - bandWidth, width: 492, height: bandWidth), CGPoint(x: 512, y: 960), CGPoint(x: 512, y: 960 - bandWidth)),
        (CGRect(x: 64, y: 266, width: bandWidth, height: 492), CGPoint(x: 64, y: 512), CGPoint(x: 64 + bandWidth, y: 512)),
        (CGRect(x: 960 - bandWidth, y: 266, width: bandWidth, height: 492), CGPoint(x: 960, y: 512), CGPoint(x: 960 - bandWidth, y: 512))
    ]
    for edge in edges {
        context.saveGState()
        context.clip(to: edge.rect)
        context.drawLinearGradient(gradient, start: edge.start, end: edge.end, options: [])
        context.restoreGState()
    }

    let cornerRadius: CGFloat = 202
    let cornerGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            glowColor.withAlphaComponent(0).cgColor,
            glowColor.withAlphaComponent(min(0.18 * glowIntensity * iconGlowGain, 1)).cgColor,
            glowColor.withAlphaComponent(min(0.5 * glowIntensity * iconGlowGain, 1)).cgColor
        ] as CFArray,
        locations: [
            (cornerRadius - bandWidth) / cornerRadius,
            (cornerRadius - 0.42 * bandWidth) / cornerRadius,
            1
        ]
    )!
    let corners: [(rect: CGRect, center: CGPoint)] = [
        (CGRect(x: 64, y: 64, width: 202, height: 202), CGPoint(x: 266, y: 266)),
        (CGRect(x: 758, y: 64, width: 202, height: 202), CGPoint(x: 758, y: 266)),
        (CGRect(x: 64, y: 758, width: 202, height: 202), CGPoint(x: 266, y: 758)),
        (CGRect(x: 758, y: 758, width: 202, height: 202), CGPoint(x: 758, y: 758))
    ]
    for corner in corners {
        context.saveGState()
        context.clip(to: corner.rect)
        context.drawRadialGradient(
            cornerGradient,
            startCenter: corner.center,
            startRadius: 0,
            endCenter: corner.center,
            endRadius: cornerRadius,
            options: []
        )
        context.restoreGState()
    }

    let border = NSBezierPath(roundedRect: NSRect(x: 66, y: 66, width: 892, height: 892), xRadius: 200, yRadius: 200)
    let borderShadow = NSShadow()
    borderShadow.shadowColor = glowColor.withAlphaComponent(min(0.55 * glowIntensity * iconGlowGain, 1))
    borderShadow.shadowBlurRadius = 18 * glowIntensity * iconGlowGain
    borderShadow.shadowOffset = .zero
    borderShadow.set()
    glowColor.withAlphaComponent(min(0.62 * glowIntensity * iconGlowGain, 1)).setStroke()
    border.lineWidth = 4.5
    border.stroke()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    let markTransform = NSAffineTransform()
    markTransform.translateX(by: 51, yBy: 48)
    markTransform.scale(by: 0.9)
    markTransform.concat()

    color(0.239, 0.580, 1.0).setFill()
    NSBezierPath(ovalIn: NSRect(x: 440, y: 752, width: 144, height: 144)).fill()

    color(0.067, 0.075, 0.090).setFill()
    NSBezierPath(ovalIn: NSRect(x: 445, y: 135, width: 134, height: 134)).fill()

    let bell = NSBezierPath()
    bell.move(to: NSPoint(x: 512, y: 206))
    bell.curve(to: NSPoint(x: 292, y: 454), controlPoint1: NSPoint(x: 375, y: 206), controlPoint2: NSPoint(x: 292, y: 309))
    bell.line(to: NSPoint(x: 292, y: 574))
    bell.curve(to: NSPoint(x: 218, y: 741), controlPoint1: NSPoint(x: 292, y: 641), controlPoint2: NSPoint(x: 265, y: 696))
    bell.curve(to: NSPoint(x: 239, y: 790), controlPoint1: NSPoint(x: 199, y: 759), controlPoint2: NSPoint(x: 212, y: 790))
    bell.line(to: NSPoint(x: 785, y: 790))
    bell.curve(to: NSPoint(x: 806, y: 741), controlPoint1: NSPoint(x: 812, y: 790), controlPoint2: NSPoint(x: 825, y: 759))
    bell.curve(to: NSPoint(x: 732, y: 574), controlPoint1: NSPoint(x: 759, y: 696), controlPoint2: NSPoint(x: 732, y: 641))
    bell.line(to: NSPoint(x: 732, y: 454))
    bell.curve(to: NSPoint(x: 512, y: 206), controlPoint1: NSPoint(x: 732, y: 309), controlPoint2: NSPoint(x: 649, y: 206))
    bell.close()
    bell.fill()

    color(0.961, 0.969, 0.980).setFill()
    let outerLoops = [
        NSRect(x: 424, y: 293, width: 176, height: 230),
        NSRect(x: 494, y: 417, width: 230, height: 176),
        NSRect(x: 424, y: 487, width: 176, height: 230),
        NSRect(x: 300, y: 417, width: 230, height: 176)
    ]
    outerLoops.forEach { NSBezierPath(ovalIn: $0).fill() }

    color(0.067, 0.075, 0.090).setFill()
    let innerLoops = [
        NSRect(x: 472, y: 341, width: 80, height: 134),
        NSRect(x: 542, y: 465, width: 134, height: 80),
        NSRect(x: 472, y: 535, width: 80, height: 134),
        NSRect(x: 348, y: 465, width: 134, height: 80)
    ]
    innerLoops.forEach { NSBezierPath(ovalIn: $0).fill() }

    NSGraphicsContext.restoreGraphicsState()

    return image
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for (name, size) in outputs {
    let image = drawIcon(size: size)
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Unable to render \(name)")
    }
    try png.write(to: outputDirectory.appending(path: name), options: .atomic)
}
