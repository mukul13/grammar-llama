import AppKit
import ApplicationServices

struct CapturedText {
    var text: String
    /// Screen rect of the selection in Cocoa coordinates (origin bottom-left), if known.
    var selectionRect: CGRect?
    var app: NSRunningApplication?
    var element: AXUIElement?
    var usedClipboard: Bool

    var appName: String { app?.localizedName ?? "" }
}

enum TextCapture {
    /// Grabs the selected text from the frontmost app. Tries the Accessibility API first,
    /// then falls back to a simulated ⌘C that preserves the user's clipboard.
    static func capture() async -> CapturedText? {
        let app = NSWorkspace.shared.frontmostApplication
        let focused = focusedElement()
        let rect = focused.flatMap(selectionRect(of:))

        if let el = focused, let text = selectedText(of: el), !text.isEmpty {
            return CapturedText(text: text, selectionRect: rect, app: app, element: el, usedClipboard: false)
        }

        if let text = await copyViaClipboard(), !text.isEmpty {
            return CapturedText(text: text, selectionRect: rect, app: app, element: focused, usedClipboard: true)
        }
        return nil
    }

    static func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var out: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &out) == .success,
              let ref = out else { return nil }
        return (ref as! AXUIElement)
    }

    static func selectedText(of element: AXUIElement) -> String? {
        var out: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &out) == .success else {
            return nil
        }
        return out as? String
    }

    static func selectionRect(of element: AXUIElement) -> CGRect? {
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeValue = rangeRef else { return nil }
        var boundsRef: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString,
                                                        rangeValue, &boundsRef) == .success,
              let boundsValue = boundsRef else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect), rect.width > 0 || rect.height > 0 else { return nil }
        return flipToCocoa(rect)
    }

    /// AX reports top-left-origin coordinates; AppKit wants bottom-left on the primary screen.
    static func flipToCocoa(_ r: CGRect) -> CGRect {
        guard let primary = NSScreen.screens.first else { return r }
        let h = primary.frame.height
        return CGRect(x: r.minX, y: h - r.maxY, width: r.width, height: r.height)
    }

    private static func copyViaClipboard() async -> String? {
        let pb = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pb)
        let before = pb.changeCount

        Keystroke.post(keyCode: 8, flags: .maskCommand) // ⌘C

        var text: String?
        for _ in 0..<15 { // up to ~300ms
            try? await Task.sleep(nanoseconds: 20_000_000)
            if pb.changeCount != before {
                text = pb.string(forType: .string)
                break
            }
        }
        snapshot.restore(to: pb)
        return text
    }
}

/// A copy of the pasteboard contents so we can put them back after borrowing it.
struct PasteboardSnapshot {
    private var items: [[NSPasteboard.PasteboardType: Data]] = []

    init(_ pb: NSPasteboard) {
        for item in pb.pasteboardItems ?? [] {
            var copy: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let d = item.data(forType: type) { copy[type] = d }
            }
            items.append(copy)
        }
    }

    func restore(to pb: NSPasteboard) {
        pb.clearContents()
        guard !items.isEmpty else { return }
        let restored: [NSPasteboardItem] = items.map { dict in
            let item = NSPasteboardItem()
            for (type, data) in dict { item.setData(data, forType: type) }
            return item
        }
        pb.writeObjects(restored)
    }
}

enum Keystroke {
    /// Posts ⌘+key as a full sequence (⌘ down, key down, key up, ⌘ up). Some apps, Electron included,
    /// ignore a bare key event that only carries the command flag.
    static func post(keyCode: CGKeyCode, flags: CGEventFlags) {
        let src = CGEventSource(stateID: .combinedSessionState)
        let cmd: CGKeyCode = 55
        guard let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: cmd, keyDown: true),
              let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false),
              let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: cmd, keyDown: false) else { return }
        cmdDown.flags = .maskCommand
        down.flags = flags
        up.flags = flags
        cmdUp.flags = []
        cmdDown.post(tap: .cghidEventTap)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        cmdUp.post(tap: .cghidEventTap)
    }
}
