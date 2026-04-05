#!/usr/bin/env swift
// Generates AppIcon.icns for the Markdown Reader app
import Cocoa

let iconsetPath = "/tmp/MarkdownReader.iconset"
try? FileManager.default.removeItem(atPath: iconsetPath)
try! FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

func createIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    let ctx = NSGraphicsContext.current!.cgContext

    // Rounded rectangle background — warm sand beige
    let bgColor = NSColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0)
    let cornerRadius = s * 0.22
    let rect = NSRect(x: 0, y: 0, width: s, height: s)
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    bgColor.setFill()
    path.fill()

    // Subtle inner shadow / border
    let borderColor = NSColor(red: 0.85, green: 0.82, blue: 0.77, alpha: 1.0)
    borderColor.setStroke()
    path.lineWidth = max(1, s * 0.015)
    path.stroke()

    // Draw "MD" text
    let fontSize = s * 0.36
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let textColor = NSColor(red: 0.42, green: 0.35, blue: 0.28, alpha: 1.0)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: textColor,
        .kern: s * -0.02
    ]
    let str: NSString = "MD"
    let strSize = str.size(withAttributes: attrs)
    let x = (s - strSize.width) / 2
    let y = (s - strSize.height) / 2 - s * 0.02
    str.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)

    // Small accent bar at bottom
    let accentColor = NSColor(red: 0.85, green: 0.48, blue: 0.29, alpha: 1.0)
    accentColor.setFill()
    let barWidth = s * 0.35
    let barHeight = s * 0.04
    let barX = (s - barWidth) / 2
    let barY = s * 0.16
    let barPath = NSBezierPath(roundedRect: NSRect(x: barX, y: barY, width: barWidth, height: barHeight),
                               xRadius: barHeight / 2, yRadius: barHeight / 2)
    barPath.fill()

    image.unlockFocus()
    return image
}

// Generate all required sizes for macOS iconset
let specs: [(name: String, size: Int)] = [
    ("icon_16x16",       16),
    ("icon_16x16@2x",    32),
    ("icon_32x32",       32),
    ("icon_32x32@2x",    64),
    ("icon_128x128",     128),
    ("icon_128x128@2x",  256),
    ("icon_256x256",     256),
    ("icon_256x256@2x",  512),
    ("icon_512x512",     512),
    ("icon_512x512@2x",  1024)
]

for spec in specs {
    let image = createIcon(size: spec.size)
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        print("Error creating \(spec.name)")
        continue
    }
    let filePath = "\(iconsetPath)/\(spec.name).png"
    try! png.write(to: URL(fileURLWithPath: filePath))
}

// Convert iconset to icns
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath, "-o", "/tmp/AppIcon.icns"]
try! process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("Icon created: /tmp/AppIcon.icns")
} else {
    print("iconutil failed with exit code \(process.terminationStatus)")
}
