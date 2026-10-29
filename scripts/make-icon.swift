import AppKit

// Usage: swift make-icon.swift <output.iconset>
let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let bg = NSBezierPath(roundedRect: NSRect(x: s * 0.05, y: s * 0.05, width: s * 0.9, height: s * 0.9),
                          xRadius: s * 0.2, yRadius: s * 0.2)
    NSGradient(colors: [NSColor(red: 0.45, green: 0.30, blue: 0.95, alpha: 1),
                        NSColor(red: 0.10, green: 0.10, blue: 0.25, alpha: 1)])!.draw(in: bg, angle: -90)
    NSColor.black.setFill()
    NSBezierPath(roundedRect: NSRect(x: s * 0.2, y: s * 0.55, width: s * 0.6, height: s * 0.2),
                 xRadius: s * 0.1, yRadius: s * 0.1).fill()
    NSColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: s * 0.28, y: s * 0.6, width: s * 0.1, height: s * 0.1)).fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: URL(fileURLWithPath: "\(out)/icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: URL(fileURLWithPath: "\(out)/icon_\(base)x\(base)@2x.png"))
}
