import AppKit
import SwiftUI

/// A borderless, non-activating floating panel. The source app keeps focus; the panel can still
/// take keyboard input because it becomes the key window without activating our process.
final class SuggestionPanel: NSPanel {
    var onKey: ((NSEvent, Bool) -> Bool)?
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        let inTextField = firstResponder is NSTextView
        if onKey?(event, inTextField) == true { return }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let inTextField = firstResponder is NSTextView
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // Only intercept command shortcuts here; plain keys flow through keyDown so text fields work.
        if flags.contains(.command), onKey?(event, inTextField) == true { return true }
        return super.performKeyEquivalent(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    static let width: CGFloat = 480

    private var panel: SuggestionPanel?
    private var hosting: NSHostingView<PanelView>?
    private var suppressHideOnResign = false

    var isVisible: Bool { panel?.isVisible ?? false }
    var currentFrame: CGRect? { panel?.isVisible == true ? panel?.frame : nil }

    func show(state: AppState, near selection: CGRect?) {
        let panel = panel ?? makePanel(state: state)
        self.panel = panel

        let screen = screenFor(selection) ?? NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame

        let size = hosting?.fittingSize ?? CGSize(width: PanelController.width, height: 160)
        applyFrame(size: size, screen: visible, animate: false)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func hide(animated: Bool = true) {
        guard let panel, panel.isVisible else { return }
        suppressHideOnResign = true
        if !animated {
            panel.orderOut(nil)
            panel.alphaValue = 0
            suppressHideOnResign = false
            return
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
                self.suppressHideOnResign = false
            }
        })
    }

    func clearFocus() {
        panel?.makeFirstResponder(nil)
    }

    /// Called by the SwiftUI content whenever its natural size changes.
    func contentSizeChanged(_ size: CGSize) {
        guard let panel, panel.isVisible else { return }
        let screen = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        applyFrame(size: size, screen: screen, animate: true)
    }

    /// Centers the panel on the screen. Re-applied as the content grows so it stays centered.
    private func applyFrame(size: CGSize, screen: CGRect, animate: Bool) {
        guard let panel else { return }
        let height = min(size.height, screen.height - 16)
        let origin = CGPoint(x: screen.midX - PanelController.width / 2,
                             y: screen.midY - height / 2)
        let frame = CGRect(origin: origin, size: CGSize(width: PanelController.width, height: height))
        if animate {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.14
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    private func screenFor(_ rect: CGRect?) -> NSScreen? {
        let point = rect.map { CGPoint(x: $0.midX, y: $0.midY) } ?? NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(point) }
    }

    private func makePanel(state: AppState) -> SuggestionPanel {
        let p = SuggestionPanel(
            contentRect: CGRect(x: 0, y: 0, width: PanelController.width, height: 160),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.hidesOnDeactivate = false
        p.isMovableByWindowBackground = true
        p.becomesKeyOnlyIfNeeded = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.animationBehavior = .none
        p.delegate = self
        p.onKey = { [weak state] event, inField in state?.handleKey(event, inTextField: inField) ?? false }
        p.onCancel = { [weak state] in
            guard let state else { return }
            if state.isEditing { state.endEditing() } else { state.hide() }
        }

        let view = NSHostingView(rootView: PanelView(state: state))
        view.sizingOptions = []
        view.translatesAutoresizingMaskIntoConstraints = true
        view.autoresizingMask = [.width, .height]
        p.contentView = view
        hosting = view
        return p
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !suppressHideOnResign else { return }
        AppState.shared.hide()
    }
}

/// Small transient confirmation shown after Replace / Copy.
@MainActor
enum Toast {
    private static var window: NSPanel?

    static func show(_ text: String, symbol: String, near frame: CGRect?) {
        window?.orderOut(nil)
        let content = HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
            Text(text).font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.primary.opacity(0.08)))

        let host = NSHostingView(rootView: content)
        let size = host.fittingSize
        let p = NSPanel(contentRect: CGRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .floating
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.contentView = host

        let anchor = frame ?? CGRect(origin: NSEvent.mouseLocation, size: .zero)
        p.setFrameOrigin(CGPoint(x: anchor.minX, y: anchor.maxY - size.height))
        p.alphaValue = 0
        p.orderFrontRegardless()
        window = p
        NSAnimationContext.runAnimationGroup { ctx in ctx.duration = 0.15; p.animator().alphaValue = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            NSAnimationContext.runAnimationGroup({ ctx in ctx.duration = 0.25; p.animator().alphaValue = 0 },
                                                completionHandler: {
                                                    Task { @MainActor in
                                                        p.orderOut(nil)
                                                        if window === p { window = nil }
                                                    }
                                                })
        }
    }
}
