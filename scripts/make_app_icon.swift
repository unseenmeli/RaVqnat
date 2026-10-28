// Renders the RaVqnat app icon (1024×1024): three overlapping circles — people meeting —
// on pomegranate red. Usage: swift scripts/make_app_icon.swift <output.png>
import AppKit

let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
NSColor(red: 0xD6/255, green: 0x3B/255, blue: 0x2F/255, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()
let r = size * 0.19
let centers = [(size * 0.5 - size * 0.13, size * 0.5 - size * 0.08, 0.95),
               (size * 0.5 + size * 0.13, size * 0.5 - size * 0.08, 0.78),
               (size * 0.5, size * 0.5 + size * 0.14, 0.6)]
for (x, y, alpha) in centers {
    NSColor(red: 1, green: 0.97, blue: 0.94, alpha: alpha).setFill()
    NSBezierPath(ovalIn: NSRect(x: x - r, y: y - r, width: r * 2, height: r * 2)).fill()
}
image.unlockFocus()
// Draw into an opaque 1024×1024 bitmap (App Store icons must not have an alpha channel).
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
                           samplesPerPixel: 3, hasAlpha: false, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
image.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024))
NSGraphicsContext.restoreGraphicsState()
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
