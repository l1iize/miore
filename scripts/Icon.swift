import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

// macOS 15 adds less visual padding than newer releases, so the artwork
// keeps its own transparent safety margin and stays balanced everywhere.
let artwork = NSRect(x: 86, y: 86, width: 852, height: 852)
NSColor(calibratedWhite: 0.025, alpha: 1).setFill()
NSBezierPath(roundedRect: artwork, xRadius: 176, yRadius: 176).fill()

let insetScale = artwork.width / size.width
func inset(_ point: NSPoint) -> NSPoint {
    NSPoint(x: artwork.minX + point.x * insetScale, y: artwork.minY + point.y * insetScale)
}
func inset(_ rect: NSRect) -> NSRect {
    NSRect(x: artwork.minX + rect.minX * insetScale, y: artwork.minY + rect.minY * insetScale,
           width: rect.width * insetScale, height: rect.height * insetScale)
}

func polygon(_ points: [NSPoint], color: NSColor) {
    let path = NSBezierPath()
    path.move(to: inset(points[0]))
    points.dropFirst().forEach { path.line(to: inset($0)) }
    path.close()
    color.setFill(); path.fill()
}

polygon([NSPoint(x: 512, y: 815), NSPoint(x: 795, y: 660), NSPoint(x: 512, y: 505), NSPoint(x: 229, y: 660)], color: .white)
polygon([NSPoint(x: 229, y: 660), NSPoint(x: 512, y: 505), NSPoint(x: 512, y: 195), NSPoint(x: 229, y: 350)], color: NSColor(calibratedWhite: 0.7, alpha: 1))
polygon([NSPoint(x: 512, y: 505), NSPoint(x: 795, y: 660), NSPoint(x: 795, y: 350), NSPoint(x: 512, y: 195)], color: NSColor(calibratedWhite: 0.42, alpha: 1))

NSColor(calibratedWhite: 0.04, alpha: 0.75).setFill()
let pixels = [(315, 622, 76, 32), (430, 696, 52, 32), (560, 645, 90, 32), (642, 534, 46, 34), (355, 458, 54, 42), (574, 342, 72, 38), (284, 382, 42, 34)]
for (x, y, w, h) in pixels { NSBezierPath(rect: inset(NSRect(x: x, y: y, width: w, height: h))).fill() }

NSColor.white.withAlphaComponent(0.88).setFill()
NSBezierPath(rect: inset(NSRect(x: 128, y: 488, width: 178, height: 14))).fill()
NSBezierPath(rect: inset(NSRect(x: 720, y: 540, width: 178, height: 11))).fill()
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Unable to create icon") }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
