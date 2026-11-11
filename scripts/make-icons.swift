// Draws the app icon and the extension icons: a dark rounded square, a white inbox tray
// and a red dot. Run from the repo root: swift scripts/make-icons.swift
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let appIconDir = root.appendingPathComponent("GitIt/Assets.xcassets/AppIcon.appiconset")
let extensionDir = root.appendingPathComponent("GitIt Extension")

func draw(size: CGFloat, macStyle: Bool) -> Data {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else { fatalError("no context") }
    context.setShouldAntialias(true)

    // macOS app icons sit inside a margin; extension icons fill the square.
    let inset = macStyle ? size * 0.1 : 0
    let frame = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = frame.width * (macStyle ? 0.225 : 0.2)

    let square = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.16, green: 0.18, blue: 0.24, alpha: 1),
        NSColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1),
    ])!
    gradient.draw(in: square, angle: -90)

    // The tray, as in the toolbar icon, scaled into the square.
    let s = frame.width / 16
    let tray = NSBezierPath()
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: frame.minX + x * s, y: frame.minY + (16 - y) * s) }
    tray.move(to: p(3.2, 2.6))
    tray.line(to: p(12.8, 2.6))
    tray.curve(to: p(14.27, 3.57), controlPoint1: p(13.5, 2.6), controlPoint2: p(14.05, 3.0))
    tray.line(to: p(15.87, 7.3))
    tray.line(to: p(16, 12.2))
    tray.curve(to: p(14, 14.2), controlPoint1: p(16, 13.3), controlPoint2: p(15.1, 14.2))
    tray.line(to: p(2, 14.2))
    tray.curve(to: p(0, 12.2), controlPoint1: p(0.9, 14.2), controlPoint2: p(0, 13.3))
    tray.line(to: p(0.13, 7.3))
    tray.line(to: p(1.73, 3.57))
    tray.curve(to: p(3.2, 2.6), controlPoint1: p(1.95, 3.0), controlPoint2: p(2.5, 2.6))
    tray.close()

    let slot = NSBezierPath()
    slot.move(to: p(3.6, 4.2))
    slot.line(to: p(2.3, 7.2))
    slot.line(to: p(5.2, 7.2))
    slot.line(to: p(6.1, 8.8))
    slot.line(to: p(9.9, 8.8))
    slot.line(to: p(10.8, 7.2))
    slot.line(to: p(13.7, 7.2))
    slot.line(to: p(12.4, 4.2))
    slot.close()
    tray.append(slot)
    tray.windingRule = .evenOdd

    // Shrink the tray toward the middle of the square.
    var transform = AffineTransform(translationByX: frame.midX, byY: frame.midY)
    transform.scale(0.62)
    transform.translate(x: -frame.midX, y: -frame.midY)
    tray.transform(using: transform)
    NSColor.white.setFill()
    tray.fill()

    // The badge dot, top right.
    let dot = frame.width * 0.26
    let dotRect = CGRect(x: frame.maxX - dot * 1.05, y: frame.maxY - dot * 1.05, width: dot, height: dot)
    NSColor(red: 0.95, green: 0.25, blue: 0.25, alpha: 1).setFill()
    NSBezierPath(ovalIn: dotRect).fill()

    image.unlockFocus()

    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func write(_ data: Data, to url: URL) {
    try! data.write(to: url)
    print("wrote \(url.path)")
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
    write(draw(size: CGFloat(size), macStyle: true), to: appIconDir.appendingPathComponent("icon-\(size).png"))
}
for size in [48, 96, 128, 256, 512] {
    write(draw(size: CGFloat(size), macStyle: false), to: extensionDir.appendingPathComponent("icon-\(size).png"))
}
