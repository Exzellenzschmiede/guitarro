// Renders the app icon (1024×1024, opaque): stage-dark background, amber glow, gradient "G", strings.
// Usage: swiftc -O -o make-app-icon Scripts/make-app-icon.swift && ./make-app-icon <output.png>
import AppKit

let size = 1024
let output = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"

guard let cgContext = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { fatalError("Could not create bitmap context") }

let context = NSGraphicsContext(cgContext: cgContext, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
let bounds = NSRect(x: 0, y: 0, width: size, height: size)

// Ink background
NSGradient(starting: NSColor(red: 0.13, green: 0.11, blue: 0.18, alpha: 1), ending: NSColor(red: 0.04, green: 0.035, blue: 0.06, alpha: 1))!
    .draw(in: bounds, angle: -90)

// Amber glow top right
let glow = NSGradient(colorsAndLocations: (NSColor(red: 0.98, green: 0.62, blue: 0.20, alpha: 0.55), 0), (NSColor(red: 0.98, green: 0.62, blue: 0.20, alpha: 0), 1))!
glow.draw(fromCenter: NSPoint(x: 780, y: 820), radius: 0, toCenter: NSPoint(x: 780, y: 820), radius: 620, options: [])
let blueGlow = NSGradient(colorsAndLocations: (NSColor(red: 0.44, green: 0.66, blue: 1.0, alpha: 0.22), 0), (NSColor(red: 0.44, green: 0.66, blue: 1.0, alpha: 0), 1))!
blueGlow.draw(fromCenter: NSPoint(x: 180, y: 160), radius: 0, toCenter: NSPoint(x: 180, y: 160), radius: 520, options: [])

// Strings, thickest on the left
for i in 0..<6 {
    let x = CGFloat(232 + i * 112)
    let path = NSBezierPath()
    path.move(to: NSPoint(x: x, y: 70))
    path.line(to: NSPoint(x: x, y: 954))
    path.lineWidth = 12 - CGFloat(i) * 1.5
    NSColor.white.withAlphaComponent(0.10).setStroke()
    path.stroke()
}

// Gradient "G": clip to the glyph outline from CoreText, then paint a gradient.
let font = NSFont.systemFont(ofSize: 640, weight: .heavy)
let ctFont = font as CTFont
var character: UniChar = 0x47 // "G"
var glyphID: CGGlyph = 0
CTFontGetGlyphsForCharacters(ctFont, &character, &glyphID, 1)
guard let glyphPath = CTFontCreatePathForGlyph(ctFont, glyphID, nil) else { fatalError("No glyph path") }
let glyphBounds = glyphPath.boundingBox
let originX = (CGFloat(size) - glyphBounds.width) / 2 - glyphBounds.minX
let originY = (CGFloat(size) - glyphBounds.height) / 2 - glyphBounds.minY + 10
var transform = CGAffineTransform(translationX: originX, y: originY)
let placedPath = glyphPath.copy(using: &transform)!

// Glow behind the glyph
cgContext.saveGState()
cgContext.setShadow(offset: CGSize(width: 0, height: -18), blur: 70, color: CGColor(red: 0.93, green: 0.40, blue: 0.11, alpha: 0.75))
cgContext.addPath(placedPath)
cgContext.setFillColor(CGColor(red: 1, green: 0.75, blue: 0.35, alpha: 1))
cgContext.fillPath()
cgContext.restoreGState()

// Gradient fill
cgContext.saveGState()
cgContext.addPath(placedPath)
cgContext.clip()
let colors = [CGColor(red: 1.0, green: 0.82, blue: 0.42, alpha: 1), CGColor(red: 0.93, green: 0.40, blue: 0.11, alpha: 1)] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1])!
cgContext.drawLinearGradient(gradient, start: CGPoint(x: placedPath.boundingBox.minX, y: placedPath.boundingBox.maxY), end: CGPoint(x: placedPath.boundingBox.maxX, y: placedPath.boundingBox.minY), options: [])
cgContext.restoreGState()

NSGraphicsContext.restoreGraphicsState()
guard let image = cgContext.makeImage() else { fatalError("Could not render image") }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("PNG encoding failed") }
try png.write(to: URL(fileURLWithPath: output))
print("wrote \(output)")
