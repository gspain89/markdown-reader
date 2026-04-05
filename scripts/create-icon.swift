#!/usr/bin/env swift
// Generates AppIcon.icns — document-page metaphor with markdown content lines
import Cocoa

let iconsetPath = "/tmp/MarkdownReader.iconset"
try? FileManager.default.removeItem(atPath: iconsetPath)
try! FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

func createIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    // ── 1. Background: warm gradient rounded rect ──
    let bg1 = NSColor(red: 0.96, green: 0.94, blue: 0.91, alpha: 1.0)
    let bg2 = NSColor(red: 0.89, green: 0.86, blue: 0.81, alpha: 1.0)
    let cornerRadius = s * 0.22
    let bgRect = NSRect(x: 0, y: 0, width: s, height: s)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)
    if let gradient = NSGradient(starting: bg1, ending: bg2) {
        gradient.draw(in: bgPath, angle: -90)
    }

    // Subtle border
    NSColor(red: 0.82, green: 0.79, blue: 0.74, alpha: 0.7).setStroke()
    bgPath.lineWidth = max(1, s * 0.008)
    bgPath.stroke()

    // ── 2. White page with drop shadow ──
    let pageInsetX = s * 0.19
    let pageInsetBottom = s * 0.14
    let pageInsetTop = s * 0.12
    let pageRect = NSRect(
        x: pageInsetX,
        y: pageInsetBottom,
        width: s - pageInsetX * 2,
        height: s - pageInsetBottom - pageInsetTop
    )
    let pageRadius = s * 0.04

    // Shadow
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.saveGState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.22)
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.02)
    shadow.shadowBlurRadius = s * 0.06
    shadow.set()

    NSColor(white: 1.0, alpha: 1.0).setFill()
    let pagePath = NSBezierPath(roundedRect: pageRect, xRadius: pageRadius, yRadius: pageRadius)
    pagePath.fill()
    ctx.restoreGState()

    // Page border
    NSColor(red: 0.88, green: 0.86, blue: 0.83, alpha: 0.5).setStroke()
    pagePath.lineWidth = max(0.5, s * 0.004)
    pagePath.stroke()

    // ── 3. Content lines on the page ──
    let contentInset = s * 0.07
    let contentLeft = pageRect.minX + contentInset
    let contentWidth = pageRect.width - contentInset * 2
    let lineH = max(1.5, s * 0.022)
    let lineGap = s * 0.048

    // "Heading" line — accent color, thicker, shorter
    let accent = NSColor(red: 0.85, green: 0.48, blue: 0.29, alpha: 1.0)
    let headingY = pageRect.maxY - s * 0.1
    let headingW = contentWidth * 0.45
    let headingH = lineH * 2.0
    accent.setFill()
    NSBezierPath(roundedRect: NSRect(x: contentLeft, y: headingY, width: headingW, height: headingH),
                 xRadius: headingH / 2, yRadius: headingH / 2).fill()

    // Body text lines — varying lengths for natural look
    let lineColor = NSColor(red: 0.80, green: 0.78, blue: 0.74, alpha: 1.0)
    lineColor.setFill()

    let lengths: [CGFloat] = [0.92, 0.78, 0.85, 0.60]
    for (i, pct) in lengths.enumerated() {
        let y = headingY - CGFloat(i + 1) * lineGap - lineGap * 0.3
        let w = contentWidth * pct
        NSBezierPath(roundedRect: NSRect(x: contentLeft, y: y, width: w, height: lineH),
                     xRadius: lineH / 2, yRadius: lineH / 2).fill()
    }

    // Gap then a second "heading" (sub-heading) — smaller accent
    let sub_headingY = headingY - CGFloat(lengths.count + 1) * lineGap - lineGap * 0.8
    let subAccent = NSColor(red: 0.85, green: 0.48, blue: 0.29, alpha: 0.7)
    subAccent.setFill()
    let subW = contentWidth * 0.35
    let subH = lineH * 1.5
    NSBezierPath(roundedRect: NSRect(x: contentLeft, y: sub_headingY, width: subW, height: subH),
                 xRadius: subH / 2, yRadius: subH / 2).fill()

    // More body lines after sub-heading
    lineColor.setFill()
    let lengths2: [CGFloat] = [0.88, 0.70, 0.82]
    for (i, pct) in lengths2.enumerated() {
        let y = sub_headingY - CGFloat(i + 1) * lineGap
        let w = contentWidth * pct
        NSBezierPath(roundedRect: NSRect(x: contentLeft, y: y, width: w, height: lineH),
                     xRadius: lineH / 2, yRadius: lineH / 2).fill()
    }

    // ── 4. Small "#" mark next to heading (visible at larger sizes) ──
    if s >= 64 {
        let hashSize = s * 0.055
        let hashFont = NSFont.systemFont(ofSize: hashSize, weight: .bold)
        let hashAttrs: [NSAttributedString.Key: Any] = [
            .font: hashFont,
            .foregroundColor: accent.withAlphaComponent(0.5)
        ]
        let hashStr: NSString = "#"
        let hashW = hashStr.size(withAttributes: hashAttrs).width
        hashStr.draw(at: NSPoint(x: contentLeft - hashW - s * 0.015, y: headingY - s * 0.008),
                     withAttributes: hashAttrs)
    }

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
