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

// Three guitars (SF Symbol "guitars.fill") as a luminance mask, painted with an amber gradient.
let symbolSize = 440.0
let configuration = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .bold)
guard let symbol = NSImage(systemSymbolName: "guitars.fill", accessibilityDescription: nil)?.withSymbolConfiguration(configuration) else {
    fatalError("Symbol not available")
}
let symbolBounds = symbol.size
let maskRect = NSRect(x: (CGFloat(size) - symbolBounds.width) / 2, y: (CGFloat(size) - symbolBounds.height) / 2 + 10, width: symbolBounds.width, height: symbolBounds.height)

// Render the symbol black on white into a gray context, then invert it so the
// glyph is white: `clip(to:mask:)` shows where the (non-mask) image is bright.
let maskContext = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
var proposed = NSRect(origin: .zero, size: symbolBounds)
guard let symbolImage = symbol.cgImage(forProposedRect: &proposed, context: nil, hints: nil) else { fatalError("Symbol raster failed") }
maskContext.setFillColor(gray: 1, alpha: 1)
maskContext.fill(CGRect(x: 0, y: 0, width: size, height: size))
maskContext.draw(symbolImage, in: maskRect)
if let data = maskContext.data {
    let bytes = data.bindMemory(to: UInt8.self, capacity: maskContext.bytesPerRow * size)
    for index in 0..<(maskContext.bytesPerRow * size) { bytes[index] = 255 - bytes[index] }
}
guard let mask = maskContext.makeImage() else { fatalError("Mask failed") }

// Glow behind the guitars
cgContext.saveGState()
cgContext.clip(to: CGRect(x: 0, y: 0, width: size, height: size), mask: mask)
cgContext.setFillColor(CGColor(red: 1, green: 0.75, blue: 0.35, alpha: 1))
cgContext.fill(CGRect(x: 0, y: 0, width: size, height: size))
cgContext.restoreGState()
cgContext.saveGState()
cgContext.setShadow(offset: CGSize(width: 0, height: -18), blur: 70, color: CGColor(red: 0.93, green: 0.40, blue: 0.11, alpha: 0.75))
cgContext.clip(to: CGRect(x: 0, y: 0, width: size, height: size), mask: mask)
cgContext.setFillColor(CGColor(red: 1, green: 0.75, blue: 0.35, alpha: 1))
cgContext.fill(CGRect(x: 0, y: 0, width: size, height: size))
cgContext.restoreGState()

// Gradient fill through the mask
cgContext.saveGState()
cgContext.clip(to: CGRect(x: 0, y: 0, width: size, height: size), mask: mask)
let colors = [CGColor(red: 1.0, green: 0.82, blue: 0.42, alpha: 1), CGColor(red: 0.93, green: 0.40, blue: 0.11, alpha: 1)] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1])!
cgContext.drawLinearGradient(gradient, start: CGPoint(x: maskRect.minX, y: maskRect.maxY), end: CGPoint(x: maskRect.maxX, y: maskRect.minY), options: [])
cgContext.restoreGState()

NSGraphicsContext.restoreGraphicsState()
guard let image = cgContext.makeImage() else { fatalError("Could not render image") }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("PNG encoding failed") }
try png.write(to: URL(fileURLWithPath: output))
print("wrote \(output)")
