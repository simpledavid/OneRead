import AppKit

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func cgGradient(_ colors: [NSColor], locations: [CGFloat]) -> CGGradient {
    let cgColors = colors.map(\.cgColor) as CFArray
    return CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: cgColors,
        locations: locations
    )!
}

func fill(_ path: NSBezierPath, with gradient: CGGradient, angle: CGFloat? = nil, context: CGContext) {
    context.saveGState()
    path.addClip()
    if let angle {
        let radians = angle * .pi / 180
        let center = CGPoint(x: path.bounds.midX, y: path.bounds.midY)
        let radius = max(path.bounds.width, path.bounds.height)
        let dx = cos(radians) * radius
        let dy = sin(radians) * radius
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: center.x - dx, y: center.y - dy),
            end: CGPoint(x: center.x + dx, y: center.y + dy),
            options: []
        )
    } else {
        context.drawRadialGradient(
            gradient,
            startCenter: CGPoint(x: path.bounds.midX, y: path.bounds.midY + 60),
            startRadius: 0,
            endCenter: CGPoint(x: path.bounds.midX, y: path.bounds.midY),
            endRadius: max(path.bounds.width, path.bounds.height) * 0.72,
            options: []
        )
    }
    context.restoreGState()
}

func stroke(_ path: NSBezierPath, color: NSColor, width: CGFloat) {
    color.setStroke()
    path.lineWidth = width
    path.stroke()
}

guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: generate_app_icon.swift <output-path>\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let canvasSize = CGSize(width: 1024, height: 1024)
let canvasRect = CGRect(origin: .zero, size: canvasSize)

guard
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasSize.width),
        pixelsHigh: Int(canvasSize.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ),
    let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)
else {
    fputs("Unable to create bitmap context.\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext
defer {
    NSGraphicsContext.restoreGraphicsState()
}

let context = graphicsContext.cgContext
context.interpolationQuality = .high
context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

let backgroundPath = NSBezierPath(rect: canvasRect)
fill(
    backgroundPath,
    with: cgGradient(
        [
            NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.12, alpha: 1),
            NSColor(calibratedRed: 0.03, green: 0.04, blue: 0.06, alpha: 1),
            NSColor(calibratedRed: 0.01, green: 0.01, blue: 0.02, alpha: 1)
        ],
        locations: [0, 0.52, 1]
    ),
    angle: 110,
    context: context
)

let glowPath = NSBezierPath(ovalIn: CGRect(x: 110, y: 440, width: 700, height: 700))
fill(
    glowPath,
    with: cgGradient(
        [
            NSColor(calibratedRed: 0.38, green: 0.55, blue: 1.0, alpha: 0.26),
            NSColor(calibratedRed: 0.18, green: 0.32, blue: 0.76, alpha: 0.10),
            NSColor(calibratedRed: 0.03, green: 0.04, blue: 0.07, alpha: 0.0)
        ],
        locations: [0, 0.58, 1]
    ),
    context: context
)

let orbPath = NSBezierPath(ovalIn: CGRect(x: 560, y: 130, width: 260, height: 260))
fill(
    orbPath,
    with: cgGradient(
        [
            NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 0.17),
            NSColor(calibratedRed: 0.72, green: 0.80, blue: 1, alpha: 0.07),
            NSColor(calibratedRed: 0.10, green: 0.14, blue: 0.24, alpha: 0.0)
        ],
        locations: [0, 0.42, 1]
    ),
    context: context
)

let cardRect = CGRect(x: 218, y: 158, width: 588, height: 708)
let cardPath = roundedRect(cardRect, radius: 158)

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -24), blur: 70, color: NSColor.black.withAlphaComponent(0.34).cgColor)
fill(
    cardPath,
    with: cgGradient(
        [
            NSColor(calibratedRed: 0.24, green: 0.28, blue: 0.40, alpha: 0.34),
            NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.28, alpha: 0.26),
            NSColor(calibratedWhite: 0.08, alpha: 0.18)
        ],
        locations: [0, 0.55, 1]
    ),
    angle: 90,
    context: context
)
context.restoreGState()

stroke(cardPath, color: NSColor.white.withAlphaComponent(0.26), width: 2.2)

let cardHighlightRect = CGRect(x: cardRect.minX + 26, y: cardRect.maxY - 138, width: cardRect.width - 120, height: 84)
let cardHighlightPath = roundedRect(cardHighlightRect, radius: 42)
fill(
    cardHighlightPath,
    with: cgGradient(
        [
            NSColor.white.withAlphaComponent(0.24),
            NSColor.white.withAlphaComponent(0.03)
        ],
        locations: [0, 1]
    ),
    angle: 0,
    context: context
)

let panelRect = cardRect.insetBy(dx: 44, dy: 44)
let panelPath = roundedRect(panelRect, radius: 118)
fill(
    panelPath,
    with: cgGradient(
        [
            NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.11, alpha: 0.96),
            NSColor(calibratedRed: 0.03, green: 0.03, blue: 0.05, alpha: 0.98)
        ],
        locations: [0, 1]
    ),
    angle: 92,
    context: context
)
stroke(panelPath, color: NSColor.white.withAlphaComponent(0.08), width: 1.2)

let topBarRect = CGRect(x: panelRect.minX + 126, y: panelRect.maxY - 126, width: 210, height: 32)
let topBarPath = roundedRect(topBarRect, radius: 16)
fill(
    topBarPath,
    with: cgGradient(
        [
            NSColor.white.withAlphaComponent(0.95),
            NSColor(calibratedRed: 0.82, green: 0.89, blue: 1.0, alpha: 0.90)
        ],
        locations: [0, 1]
    ),
    angle: 0,
    context: context
)

let stemRect = CGRect(x: panelRect.midX - 42, y: panelRect.minY + 178, width: 84, height: 318)
let stemPath = roundedRect(stemRect, radius: 42)
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -10), blur: 26, color: NSColor(calibratedRed: 0.62, green: 0.76, blue: 1, alpha: 0.38).cgColor)
fill(
    stemPath,
    with: cgGradient(
        [
            NSColor.white.withAlphaComponent(0.98),
            NSColor(calibratedRed: 0.83, green: 0.90, blue: 1.0, alpha: 0.94)
        ],
        locations: [0, 1]
    ),
    angle: 90,
    context: context
)
context.restoreGState()

let lines = [
    CGRect(x: panelRect.minX + 118, y: panelRect.minY + 104, width: panelRect.width - 236, height: 24),
    CGRect(x: panelRect.minX + 118, y: panelRect.minY + 58, width: panelRect.width - 236, height: 24),
    CGRect(x: panelRect.minX + 170, y: panelRect.minY + 12, width: panelRect.width - 340, height: 24)
]

for (index, rect) in lines.enumerated() {
    let linePath = roundedRect(rect, radius: 12)
    let alpha = 0.82 - CGFloat(index) * 0.12
    fill(
        linePath,
        with: cgGradient(
            [
                NSColor.white.withAlphaComponent(alpha),
                NSColor(calibratedRed: 0.83, green: 0.89, blue: 1.0, alpha: alpha * 0.9)
            ],
            locations: [0, 1]
        ),
        angle: 0,
        context: context
    )
}

let specularPath = NSBezierPath(ovalIn: CGRect(x: panelRect.minX + 56, y: panelRect.maxY - 214, width: 180, height: 96))
fill(
    specularPath,
    with: cgGradient(
        [
            NSColor.white.withAlphaComponent(0.16),
            NSColor.white.withAlphaComponent(0.0)
        ],
        locations: [0, 1]
    ),
    angle: 12,
    context: context
)

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to render PNG output.\n", stderr)
    exit(1)
}

try pngData.write(to: outputURL)
