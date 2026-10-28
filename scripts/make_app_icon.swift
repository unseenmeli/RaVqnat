// Renders the RaVqnat app icon (1024×1024, opaque): three paper circles — people meeting —
// on ink, with two pink afterimages trailing left (the "echo").
// Usage: swift scripts/make_app_icon.swift icon.png && sips -s format jpeg icon.png --out icon.jpg && sips -s format png icon.jpg --out icon.png
// (the sips round-trip removes the alpha channel, which App Store icons must not have)
import AppKit

let size = 1024.0
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func color(_ hex: Int, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let ink = color(0x111111), paper = color(0xF5F4F0), pink = 0xFF2E9A
ink.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

// Faint dot grid, like ECHO's paper.
color(0xF5F4F0, 0.08).setFill()
stride(from: 32.0, to: size, by: 48).forEach { x in
    stride(from: 32.0, to: size, by: 48).forEach { y in
        NSBezierPath(ovalIn: NSRect(x: x - 3, y: y - 3, width: 6, height: 6)).fill()
    }
}

let r = size * 0.15
let centre = (x: size * 0.56, y: size * 0.5)
let circles = [(centre.x - size * 0.11, centre.y - size * 0.07), (centre.x + size * 0.11, centre.y - size * 0.07),
               (centre.x, centre.y + size * 0.12)]

func drawCircles(dx: CGFloat, fill: NSColor) {
    fill.setFill()
    for (x, y) in circles {
        NSBezierPath(ovalIn: NSRect(x: x - r + dx, y: y - r, width: r * 2, height: r * 2)).fill()
    }
}

drawCircles(dx: -size * 0.12, fill: color(pink, 0.35))
drawCircles(dx: -size * 0.06, fill: color(pink, 0.9))
drawCircles(dx: 0, fill: paper)
// Ink outlines keep the three people distinct where they overlap.
ink.setStroke()
for (x, y) in circles {
    let path = NSBezierPath(ovalIn: NSRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    path.lineWidth = 14
    path.stroke()
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
