import AppKit

// Minimal pure black-and-white OneRead icon: solid #000000 background with a
// pure #FFFFFF "article" glyph (a bold title bar over three text lines). No
// gradients, glows, or tints — true black, true white.

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
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

// Pure black background.
NSColor.black.setFill()
NSBezierPath(rect: canvasRect).fill()

// Pure white article glyph.
NSColor.white.setFill()

func bar(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
    roundedRect(CGRect(x: x, y: y, width: width, height: height), radius: height / 2).fill()
}

// Bold title bar, then three body lines (last shorter) evenly spaced below.
bar(x: 300, y: 612, width: 300, height: 72)
bar(x: 300, y: 506, width: 424, height: 48)
bar(x: 300, y: 426, width: 424, height: 48)
bar(x: 300, y: 346, width: 300, height: 48)

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to render PNG output.\n", stderr)
    exit(1)
}

try pngData.write(to: outputURL)
