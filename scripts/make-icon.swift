import AppKit

let directory = CommandLine.arguments[1]
let sizes = [16, 32, 128, 256, 512]
try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
for base in sizes {
    for multiplier in [1, 2] {
        let size = base * multiplier
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
        let scale = CGFloat(size) / 1024
        context.cgContext.scaleBy(x: scale, y: scale)
        let rect = NSRect(x: 50, y: 50, width: 924, height: 924)
        let path = NSBezierPath(roundedRect: rect, xRadius: 224, yRadius: 224)
        NSGradient(starting: NSColor(srgbRed: 0.24, green: 0.28, blue: 0.82, alpha: 1), ending: NSColor(srgbRed: 0.30, green: 0.56, blue: 1, alpha: 1))!.draw(in: path, angle: 70)
        NSColor.white.withAlphaComponent(0.24).setStroke(); path.lineWidth = 2; path.stroke()
        let arc = NSBezierPath()
        arc.appendArc(withCenter: NSPoint(x: 498, y: 512), radius: 237, startAngle: 44, endAngle: 316, clockwise: false)
        arc.lineWidth = 84; arc.lineCapStyle = .round
        NSColor.white.setStroke(); arc.stroke()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: 686, y: 462, width: 100, height: 100)).fill()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = multiplier == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(directory)/icon_\(base)x\(base)\(suffix).png"))
    }
}
