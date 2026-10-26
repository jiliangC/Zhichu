import AppKit

/// The approved app mark, simplified for an 18 pt menu item: two open flaps, a box and a found dot.
/// A transparent, monochrome template lets macOS choose the right ink for light/dark menu bars.
enum StatusIcon {
    static func image(progress: Double?, paused: Bool = false, update: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }
            let transform = AffineTransform(translationByX: rect.minX, byY: rect.minY)
            (transform as NSAffineTransform).concat()
            let scale = NSAffineTransform()
            scale.scaleX(by: rect.width / 18, yBy: rect.height / 18)
            scale.concat()

            if let progress, !paused {
                drawMark(alpha: 0.28, paused: false)
                NSGraphicsContext.saveGraphicsState()
                let reached = NSBezierPath()
                reached.move(to: NSPoint(x: 9, y: 9))
                reached.appendArc(withCenter: NSPoint(x: 9, y: 9), radius: 18, startAngle: 90,
                                  endAngle: 90 - 360 * min(1, max(0, progress)), clockwise: true)
                reached.close()
                reached.addClip()
                drawMark(alpha: 1, paused: false)
                NSGraphicsContext.restoreGraphicsState()
            } else {
                drawMark(alpha: 1, paused: paused)
            }
            if update {
                NSGraphicsContext.current?.compositingOperation = .clear
                NSBezierPath(ovalIn: NSRect(x: 12, y: 12, width: 6, height: 6)).fill()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
                NSColor.black.setFill()
                NSBezierPath(ovalIn: NSRect(x: 13.25, y: 13.25, width: 3.5, height: 3.5)).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = paused ? "知处，索引已暂停" : "知处"
        return image
    }

    private static func drawMark(alpha: CGFloat, paused: Bool) {
        NSColor.black.withAlphaComponent(alpha).setFill()

        // Trace the application's open left flap, then reflect it for the right flap.
        let flap = NSBezierPath()
        flap.move(to: NSPoint(x: 1.7, y: 8.8))
        flap.curve(to: NSPoint(x: 1.15, y: 9.55), controlPoint1: NSPoint(x: 1.05, y: 8.45),
                   controlPoint2: NSPoint(x: 0.85, y: 8.85))
        flap.line(to: NSPoint(x: 1.9, y: 12.05))
        flap.curve(to: NSPoint(x: 2.9, y: 13.3), controlPoint1: NSPoint(x: 2.1, y: 12.65),
                   controlPoint2: NSPoint(x: 2.35, y: 13.0))
        flap.line(to: NSPoint(x: 7.3, y: 15.65))
        flap.curve(to: NSPoint(x: 8.15, y: 15.0), controlPoint1: NSPoint(x: 8.05, y: 16.05),
                   controlPoint2: NSPoint(x: 8.5, y: 15.7))
        flap.line(to: NSPoint(x: 7.3, y: 12.85))
        flap.curve(to: NSPoint(x: 6.75, y: 12.3), controlPoint1: NSPoint(x: 7.15, y: 12.55),
                   controlPoint2: NSPoint(x: 7.0, y: 12.45))
        flap.close()
        flap.fill()
        let mirrored = flap.copy() as! NSBezierPath
        mirrored.transform(using: AffineTransform(m11: -1, m12: 0, m21: 0, m22: 1, tX: 18, tY: 0))
        mirrored.fill()

        let box = NSBezierPath()
        box.move(to: NSPoint(x: 2.55, y: 8.35))
        box.curve(to: NSPoint(x: 3.15, y: 8.75), controlPoint1: NSPoint(x: 2.55, y: 8.7),
                  controlPoint2: NSPoint(x: 2.85, y: 8.9))
        box.line(to: NSPoint(x: 8.55, y: 6.5))
        box.curve(to: NSPoint(x: 9.45, y: 6.5), controlPoint1: NSPoint(x: 8.85, y: 6.38),
                  controlPoint2: NSPoint(x: 9.15, y: 6.38))
        box.line(to: NSPoint(x: 14.85, y: 8.75))
        box.curve(to: NSPoint(x: 15.45, y: 8.35), controlPoint1: NSPoint(x: 15.15, y: 8.9),
                  controlPoint2: NSPoint(x: 15.45, y: 8.7))
        box.line(to: NSPoint(x: 15.45, y: 4.8))
        box.curve(to: NSPoint(x: 14.8, y: 3.8), controlPoint1: NSPoint(x: 15.45, y: 4.3),
                  controlPoint2: NSPoint(x: 15.25, y: 4.0))
        box.line(to: NSPoint(x: 9.65, y: 1.5))
        box.curve(to: NSPoint(x: 8.35, y: 1.5), controlPoint1: NSPoint(x: 9.2, y: 1.3),
                  controlPoint2: NSPoint(x: 8.8, y: 1.3))
        box.line(to: NSPoint(x: 3.2, y: 3.8))
        box.curve(to: NSPoint(x: 2.55, y: 4.8), controlPoint1: NSPoint(x: 2.75, y: 4.0),
                  controlPoint2: NSPoint(x: 2.55, y: 4.3))
        box.close()
        box.fill()

        if paused {
            for x: CGFloat in [7.6, 9.3] {
                NSBezierPath(roundedRect: NSRect(x: x, y: 8.1, width: 1.1, height: 2.8),
                             xRadius: 0.35, yRadius: 0.35).fill()
            }
        } else {
            NSBezierPath(ovalIn: NSRect(x: 7.55, y: 8.05, width: 2.9, height: 2.9)).fill()
        }
    }
}
