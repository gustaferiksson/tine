import AppKit
import ApplicationServices

/// Locates the text caret of the focused UI element via the Accessibility API.
enum AXCaret {
    static func ensureTrusted() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Top-left point (Cocoa, bottom-left origin) just below the caret, or nil.
    static func caretTopLeftBelow(gap: CGFloat = 4) -> NSPoint? {
        let app = NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
        let system = AXUIElementCreateSystemWide()

        var focused: CFTypeRef?
        let fErr = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused)
        guard fErr == .success, let focusedRef = focused else {
            tlog("AX[\(app)] focusedElement FAILED err=\(fErr.rawValue)")
            return nil
        }
        let element = focusedRef as! AXUIElement

        var rangeRef: CFTypeRef?
        let rErr = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef)
        guard rErr == .success, let rangeVal = rangeRef else {
            tlog("AX[\(app)] selectedRange FAILED err=\(rErr.rawValue)")
            return nil
        }

        var caret = CFRange(location: 0, length: 0)
        AXValueGetValue(rangeVal as! AXValue, .cfRange, &caret)

        // 1) Try the caret range directly (works in iTerm2). anchorAtRightEdge=false.
        // 2) If it yields an empty/zero-height rect (Terminal.app), probe the
        //    character *before* the caret and anchor to its right edge.
        // 3) Otherwise probe the character *after* the caret.
        var anchorRight = false
        var rect = bounds(element, CFRange(location: caret.location, length: 0))
        if !valid(rect) && caret.location > 0 {
            rect = bounds(element, CFRange(location: caret.location - 1, length: 1))
            anchorRight = true
        }
        if !valid(rect) {
            rect = bounds(element, CFRange(location: caret.location, length: 1))
            anchorRight = false
        }
        guard let r = rect, valid(r) else {
            tlog("AX[\(app)] no valid bounds for caret \(caret)")
            return nil
        }

        let primaryHeight = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.main?.frame.height ?? 0
        let anchorX = anchorRight ? r.maxX : r.minX
        let caretBottomCocoaY = primaryHeight - (r.origin.y + r.height)
        let point = NSPoint(x: anchorX, y: caretBottomCocoaY - gap)

        tlog("AX[\(app)] caret=\(caret) rect=\(r) anchorRight=\(anchorRight) -> \(point)")
        return point
    }

    private static func valid(_ rect: CGRect?) -> Bool {
        guard let r = rect else { return false }
        return r.origin.x.isFinite && r.origin.y.isFinite && r.height > 0
    }

    private static func bounds(_ element: AXUIElement, _ range: CFRange) -> CGRect? {
        var r = range
        guard let value = AXValueCreate(.cfRange, &r) else { return nil }
        var out: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
                element, kAXBoundsForRangeParameterizedAttribute as CFString, value, &out) == .success,
              let boundsVal = out else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(boundsVal as! AXValue, .cgRect, &rect) else { return nil }
        return rect
    }
}
