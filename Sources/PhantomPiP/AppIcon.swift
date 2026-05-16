import AppKit

/// The app icon, drawn in code so there's no asset to ship and it works with
/// a bare `swift run` binary (no .app bundle). A phantom-themed indigo→violet
/// squircle with a glowing ghost 👻.
enum AppIcon {

    /// NSImage for `NSApp.applicationIconImage` (Dock / ⌘-Tab).
    static func make(size: CGFloat = 1024) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            draw(in: rect)
            return true
        }
    }

    /// Render to a PNG file (used by `--export-icon`; handy for building a
    /// real .icns if you ever bundle this into a .app).
    @discardableResult
    static func export(to path: String, pixels: Int = 1024) -> Bool {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0)
        else { return false }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()

        guard let png = rep.representation(using: .png, properties: [:]) else { return false }
        do {
            try png.write(to: URL(fileURLWithPath: path))
            return true
        } catch {
            return false
        }
    }

    // MARK: - Drawing

    private static func draw(in rect: NSRect) {
        let w = rect.width

        // Squircle-ish rounded-rect mask (Apple's grid ≈ 0.2237 × size).
        let clip = NSBezierPath(roundedRect: rect,
                                xRadius: w * 0.2237,
                                yRadius: w * 0.2237)
        clip.addClip()

        // Indigo → violet vertical gradient backdrop.
        NSGradient(colors: [
            NSColor(srgbRed: 0.12, green: 0.10, blue: 0.27, alpha: 1),
            NSColor(srgbRed: 0.37, green: 0.27, blue: 0.68, alpha: 1),
        ])?.draw(in: rect, angle: -90)

        // Soft ghostly aura behind the emoji.
        let auraCenter = NSPoint(x: rect.midX, y: rect.midY + w * 0.04)
        NSGradient(starting: NSColor(white: 1, alpha: 0.30),
                   ending: NSColor(white: 1, alpha: 0))?
            .draw(fromCenter: auraCenter, radius: 0,
                  toCenter: auraCenter, radius: w * 0.46, options: [])

        // The ghost.
        let emoji = "👻" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: w * 0.56)
        ]
        let textSize = emoji.size(withAttributes: attrs)
        let origin = NSPoint(x: rect.midX - textSize.width / 2,
                             y: rect.midY - textSize.height / 2 + w * 0.03)

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.32)
        shadow.shadowBlurRadius = w * 0.03
        shadow.shadowOffset = NSSize(width: 0, height: -w * 0.015)

        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        emoji.draw(at: origin, withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()

        // Faint inner edge sheen, like stock macOS icons.
        let edge = NSBezierPath(roundedRect: rect.insetBy(dx: w * 0.006, dy: w * 0.006),
                                xRadius: w * 0.2237, yRadius: w * 0.2237)
        edge.lineWidth = w * 0.012
        NSColor(white: 1, alpha: 0.10).setStroke()
        edge.stroke()
    }
}
