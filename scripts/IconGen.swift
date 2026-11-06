import AppKit
import Foundation

// Renders the 1024x1024 master app icon for TidyMac.
// Run via scripts/make_icon.sh.

let side = 1024
let canvasRect = NSRect(x: 0, y: 0, width: side, height: side)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                 pixelsWide: side, pixelsHigh: side,
                                 bitsPerSample: 8, samplesPerPixel: 4,
                                 hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .deviceRGB,
                                 bytesPerRow: 0, bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: rep) else {
    fatalError("Could not create bitmap context")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high

NSColor.clear.setFill()
canvasRect.fill()

// Icon plate: macOS-style rounded square with generous transparent padding.
let margin: CGFloat = 92
let plate = NSRect(x: margin, y: margin, width: CGFloat(side) - margin * 2, height: CGFloat(side) - margin * 2)
let corner: CGFloat = 188
let platePath = NSBezierPath(roundedRect: plate, xRadius: corner, yRadius: corner)

// Soft drop shadow beneath the plate.
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
shadow.shadowBlurRadius = 46
shadow.shadowOffset = NSSize(width: 0, height: -20)
shadow.set()
color(0x050B10).setFill()
platePath.fill()
NSGraphicsContext.restoreGraphicsState()

// Clip everything else to the plate.
NSGraphicsContext.saveGraphicsState()
platePath.addClip()

// Base gradient.
let background = NSGradient(colors: [color(0x0C2029), color(0x071018)])!
background.draw(in: plate, angle: -90)

func glow(center: NSPoint, radius: CGFloat, tint: NSColor, alpha: CGFloat) {
    let rect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    let gradient = NSGradient(colors: [tint.withAlphaComponent(alpha), tint.withAlphaComponent(0)])!
    gradient.draw(in: NSBezierPath(ovalIn: rect), relativeCenterPosition: .zero)
}

glow(center: NSPoint(x: 290, y: 300), radius: 520, tint: color(0x5CE8C4), alpha: 0.40)
glow(center: NSPoint(x: 790, y: 760), radius: 470, tint: color(0x4BA3FF), alpha: 0.34)
glow(center: NSPoint(x: 170, y: 830), radius: 320, tint: color(0xA78BFA), alpha: 0.16)

// Faint orbital rings for depth.
NSGraphicsContext.saveGraphicsState()
NSColor.white.withAlphaComponent(0.045).setStroke()
for index in 0..<4 {
    let inset = CGFloat(index) * 86
    let ring = NSBezierPath(ovalIn: plate.insetBy(dx: inset + 120, dy: inset + 120))
    ring.lineWidth = 2
    ring.stroke()
}
NSGraphicsContext.restoreGraphicsState()

// Aurora sweep.
let sweepPath = NSBezierPath()
sweepPath.move(to: NSPoint(x: plate.minX, y: plate.minY + 160))
sweepPath.curve(to: NSPoint(x: plate.maxX, y: plate.minY + 430),
                controlPoint1: NSPoint(x: 380, y: plate.minY + 60),
                controlPoint2: NSPoint(x: 700, y: plate.minY + 560))
sweepPath.line(to: NSPoint(x: plate.maxX, y: plate.minY))
sweepPath.line(to: NSPoint(x: plate.minX, y: plate.minY))
sweepPath.close()
let sweepGradient = NSGradient(colors: [color(0x5CE8C4, 0.07), color(0x4BA3FF, 0.02)])!
sweepGradient.draw(in: sweepPath, angle: 0)
NSGraphicsContext.restoreGraphicsState()

// Inner highlight border.
NSGraphicsContext.saveGraphicsState()
platePath.addClip()
NSColor.white.withAlphaComponent(0.13).setStroke()
let inner = NSBezierPath(roundedRect: plate.insetBy(dx: 2.5, dy: 2.5),
                         xRadius: corner - 2.5, yRadius: corner - 2.5)
inner.lineWidth = 2
inner.stroke()
NSGraphicsContext.restoreGraphicsState()

// Feather mark, drawn by hand so it stays crisp at every size.
func drawFeather() {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: 512, yBy: 512)
    transform.rotate(byDegrees: -15)
    transform.concat()

    // Vane: a pointed leaf silhouette.
    let vane = NSBezierPath()
    vane.move(to: NSPoint(x: 0, y: 292))
    vane.curve(to: NSPoint(x: 0, y: -278),
               controlPoint1: NSPoint(x: 128, y: 166),
               controlPoint2: NSPoint(x: 96, y: -82))
    vane.curve(to: NSPoint(x: 0, y: 292),
               controlPoint1: NSPoint(x: -104, y: -104),
               controlPoint2: NSPoint(x: -150, y: 156))
    vane.close()

    NSGraphicsContext.saveGraphicsState()
    let featherShadow = NSShadow()
    featherShadow.shadowColor = color(0x5CE8C4, 0.5)
    featherShadow.shadowBlurRadius = 38
    featherShadow.set()
    let vaneGradient = NSGradient(colors: [NSColor.white, color(0xC9FFF2), color(0x5CE8C4)])!
    vaneGradient.draw(in: vane, angle: 84)
    NSGraphicsContext.restoreGraphicsState()

    // Barbs.
    NSGraphicsContext.saveGraphicsState()
    vane.addClip()
    color(0x083A34, 0.22).setStroke()
    for index in 0..<13 {
        let y = -196 + CGFloat(index) * 36
        let halfWidth: CGFloat = 108 * (1 - pow(abs(y + 20) / 290, 1.6)) + 6
        let barb = NSBezierPath()
        barb.move(to: NSPoint(x: 0, y: y))
        barb.curve(to: NSPoint(x: halfWidth, y: y + 52),
                   controlPoint1: NSPoint(x: halfWidth * 0.3, y: y + 8),
                   controlPoint2: NSPoint(x: halfWidth * 0.7, y: y + 28))
        barb.lineWidth = 3
        barb.stroke()
        let mirrored = NSBezierPath()
        mirrored.move(to: NSPoint(x: 0, y: y))
        mirrored.curve(to: NSPoint(x: -halfWidth, y: y + 52),
                       controlPoint1: NSPoint(x: -halfWidth * 0.3, y: y + 8),
                       controlPoint2: NSPoint(x: -halfWidth * 0.7, y: y + 28))
        mirrored.lineWidth = 3
        mirrored.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()

    // Quill.
    NSGraphicsContext.saveGraphicsState()
    let quill = NSBezierPath()
    quill.move(to: NSPoint(x: 0, y: -310))
    quill.curve(to: NSPoint(x: 0, y: 306),
                controlPoint1: NSPoint(x: 6, y: -80),
                controlPoint2: NSPoint(x: -4, y: 150))
    color(0x0A2C28, 0.65).setStroke()
    quill.lineWidth = 9
    quill.lineCapStyle = .round
    quill.stroke()
    color(0xDFFFF6, 0.9).setStroke()
    quill.lineWidth = 2.5
    quill.stroke()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
}
drawFeather()

// Four-point sparkle helper.
func sparkle(center: NSPoint, radius: CGFloat, tint: NSColor) {
    let c = radius * 0.12
    let path = NSBezierPath()
    path.move(to: NSPoint(x: center.x, y: center.y + radius))
    path.curve(to: NSPoint(x: center.x + radius, y: center.y),
               controlPoint1: NSPoint(x: center.x + c, y: center.y + c),
               controlPoint2: NSPoint(x: center.x + c, y: center.y + c))
    path.curve(to: NSPoint(x: center.x, y: center.y - radius),
               controlPoint1: NSPoint(x: center.x + c, y: center.y - c),
               controlPoint2: NSPoint(x: center.x + c, y: center.y - c))
    path.curve(to: NSPoint(x: center.x - radius, y: center.y),
               controlPoint1: NSPoint(x: center.x - c, y: center.y - c),
               controlPoint2: NSPoint(x: center.x - c, y: center.y - c))
    path.curve(to: NSPoint(x: center.x, y: center.y + radius),
               controlPoint1: NSPoint(x: center.x - c, y: center.y + c),
               controlPoint2: NSPoint(x: center.x - c, y: center.y + c))
    path.close()

    NSGraphicsContext.saveGraphicsState()
    let sparkleShadow = NSShadow()
    sparkleShadow.shadowColor = tint.withAlphaComponent(0.8)
    sparkleShadow.shadowBlurRadius = 30
    sparkleShadow.set()
    tint.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
}

NSGraphicsContext.saveGraphicsState()
platePath.addClip()
sparkle(center: NSPoint(x: 742, y: 730), radius: 92, tint: NSColor.white)
sparkle(center: NSPoint(x: 842, y: 842), radius: 38, tint: color(0xB9FFEE))
sparkle(center: NSPoint(x: 238, y: 782), radius: 24, tint: color(0x7FE9FF))
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode PNG")
}
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"
try data.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
