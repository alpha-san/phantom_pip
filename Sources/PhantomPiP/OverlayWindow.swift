import AppKit

/// Borderless windows return false from `canBecomeKey`/`canBecomeMain` by
/// default, which would stop the URL field from accepting text. Override so
/// the phantom window can take keyboard focus when it is interactive.
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// A small draggable grip in the bottom-right corner. A near-invisible
/// borderless window is hard to grab by its edges, so this gives the user a
/// reliable resize affordance.
final class ResizeGrip: NSView {
    private var startMouse: NSPoint = .zero
    private var startFrame: NSRect = .zero

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        startMouse = NSEvent.mouseLocation
        startFrame = window.frame
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - startMouse.x
        let dy = now.y - startMouse.y

        var frame = startFrame
        let newWidth = max(window.minSize.width, startFrame.width + dx)
        let newHeight = max(window.minSize.height, startFrame.height - dy)
        frame.size.width = newWidth
        frame.size.height = newHeight
        // Keep the top-left corner anchored while dragging the bottom-right.
        frame.origin.y = startFrame.origin.y + (startFrame.height - newHeight)
        window.setFrame(frame, display: true)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.withAlphaComponent(0.45).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1
        var offset: CGFloat = 3
        while offset <= bounds.width {
            path.move(to: NSPoint(x: bounds.maxX - offset, y: 2))
            path.line(to: NSPoint(x: bounds.maxX - 2, y: offset))
            offset += 4
        }
        path.stroke()
    }
}
