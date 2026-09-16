import AppKit
import ApplicationServices

enum TextInsert {
    enum Outcome { case replaced, copied }

    /// Replaces the selection in the source app with `text`. Falls back to copying when
    /// the field is read-only or no target is known.
    static func replace(_ text: String, in capture: CapturedText?) async -> Outcome {
        guard let capture, let app = capture.app else {
            log.error("replace: no capture/app, copying instead")
            copy(text)
            return .copied
        }

        let front = NSWorkspace.shared.frontmostApplication
        log.notice("replace: target=\(app.localizedName ?? "?", privacy: .public) front=\(front?.localizedName ?? "?", privacy: .public) usedClipboard=\(capture.usedClipboard) alwaysPaste=\(Prefs.alwaysPaste)")

        // Make sure the source app is still in front. Our panel never activates us, but the user
        // may have clicked elsewhere.
        if front?.processIdentifier != app.processIdentifier {
            await MainActor.run { NSApp.yieldActivation(to: app) }
            let ok = app.activate()
            log.notice("replace: re-activating target app -> \(ok)")
            try? await Task.sleep(nanoseconds: 200_000_000)
        } else {
            // Give the source app a moment to become key again before keystrokes land.
            try? await Task.sleep(nanoseconds: 150_000_000)
        }

        // Accessibility insert only when Accessibility could read the selection in the first place.
        // Electron and other web views accept the write and silently drop it, so the write must verify.
        if !Prefs.alwaysPaste, !capture.usedClipboard, let el = capture.element,
           setViaAX(text, on: el, original: capture.text) {
            log.notice("replace: inserted via Accessibility")
            return .replaced
        }

        log.notice("replace: pasting via ⌘V")
        return await paste(text) ? .replaced : .copied
    }

    static func copy(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    private static func setViaAX(_ text: String, on element: AXUIElement, original: String) -> Bool {
        var settable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable) == .success,
              settable.boolValue else { return false }
        let status = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        guard status == .success else { return false }
        // Some apps report success but do nothing. Verify by reading the value back; if the value
        // is not exposed, the selection must at least no longer be the original text.
        var out: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &out) == .success,
           let value = out as? String {
            return value.contains(text)
        }
        if let selected = TextCapture.selectedText(of: element) {
            return selected != original
        }
        return false
    }

    private static func paste(_ text: String) async -> Bool {
        let pb = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pb)
        pb.clearContents()
        pb.setString(text, forType: .string)
        let count = pb.changeCount
        Keystroke.post(keyCode: 9, flags: .maskCommand) // ⌘V
        try? await Task.sleep(nanoseconds: 500_000_000)
        log.notice("replace: pasted (pasteboard changeCount \(count)), restoring clipboard")
        snapshot.restore(to: pb)
        return true
    }
}
