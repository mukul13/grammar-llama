import AppKit
import SwiftUI

struct Variant: Identifiable {
    let id = UUID()
    var label: String
    var flavor: VariantFlavor
    var text: String = ""
    var isStreaming = true
    var error: String?
    var edited = false
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var variants: [Variant] = []
    @Published var selectedIndex = 0
    @Published var isEditing = false
    @Published var showDiff = Prefs.showDiffByDefault
    @Published var tweaks: [String] = []
    @Published var instruction = ""
    @Published var banner: String?          // non-fatal message shown at the top of the panel
    @Published var original = ""
    @Published var sourceAppName = ""

    let panel = PanelController()
    private(set) var capture: CapturedText?
    private var tasks: [UUID: Task<Void, Never>] = [:]

    var isStreaming: Bool { variants.contains { $0.isStreaming } }
    var currentText: String { variants.indices.contains(selectedIndex) ? variants[selectedIndex].text : "" }

    // MARK: - Entry

    func trigger() {
        log.notice("trigger: trusted=\(Permissions.isTrusted) panelVisible=\(self.panel.isVisible)")
        guard Permissions.isTrusted else { Onboarding.show(); return }
        if panel.isVisible { hide(); return }

        Task {
            guard let cap = await TextCapture.capture() else {
                log.notice("capture: nothing selected")
                showMessage("Select some text first, then press \(Prefs.hotKey.display).")
                return
            }
            log.notice("capture: \(cap.text.count) chars from \(cap.appName, privacy: .public) clipboard=\(cap.usedClipboard)")
            start(with: cap)
        }
    }

    func start(with cap: CapturedText) {
        cancelAll()
        capture = cap
        original = cap.text
        sourceAppName = cap.appName
        tweaks = []
        instruction = ""
        isEditing = false
        selectedIndex = 0
        banner = nil
        panel.show(state: self, near: cap.selectionRect)
        runAll()
    }

    private func showMessage(_ text: String) {
        cancelAll()
        capture = nil
        original = ""
        variants = []
        banner = text
        panel.show(state: self, near: nil)
        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if self.variants.isEmpty { self.hide() }
        }
    }

    func hide(animated: Bool = true) {
        cancelAll()
        isEditing = false
        panel.hide(animated: animated)
    }

    // MARK: - Generation

    func runAll() {
        cancelAll()
        let flavors = VariantFlavor.flavors(count: Prefs.variantCount)
        variants = flavors.map { Variant(label: $0.label, flavor: $0) }
        selectedIndex = 0
        for v in variants { launch(v.id) }
    }

    func regenerate(_ index: Int) {
        guard variants.indices.contains(index) else { return }
        variants[index].text = ""
        variants[index].error = nil
        variants[index].edited = false
        variants[index].isStreaming = true
        launch(variants[index].id)
    }

    private func launch(_ id: UUID) {
        tasks[id]?.cancel()
        guard let client = LLM.fromSettings else {
            update(id) { $0.isStreaming = false; $0.error = ClaudeError.missingKey.localizedDescription }
            return
        }
        guard let variant = variants.first(where: { $0.id == id }) else { return }
        let system = RewriteEngine.systemPrompt(flavor: variant.flavor, tweaks: tweaks, appName: sourceAppName)
        let user = RewriteEngine.userMessage(original)

        tasks[id] = Task { [weak self] in
            do {
                for try await delta in client.stream(system: system, user: user) {
                    guard !Task.isCancelled else { return }
                    self?.update(id) { $0.text += delta }
                }
                self?.update(id) { $0.text = RewriteEngine.clean($0.text); $0.isStreaming = false }
            } catch is CancellationError {
            } catch {
                self?.update(id) { $0.isStreaming = false; $0.error = error.localizedDescription }
            }
        }
    }

    private func update(_ id: UUID, _ change: (inout Variant) -> Void) {
        guard let i = variants.firstIndex(where: { $0.id == id }) else { return }
        change(&variants[i])
    }

    private func cancelAll() {
        tasks.values.forEach { $0.cancel() }
        tasks = [:]
    }

    // MARK: - Tweaks

    func submitInstruction() {
        let t = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        instruction = ""
        applyTweak(t)
    }

    func applyTweak(_ t: String) {
        guard !tweaks.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) else { return }
        tweaks.append(t)
        isEditing = false
        runAll()
    }

    func removeTweak(_ t: String) {
        tweaks.removeAll { $0 == t }
        isEditing = false
        runAll()
    }

    // MARK: - Selection & editing

    func select(_ index: Int) {
        guard variants.indices.contains(index) else { return }
        if isEditing, index != selectedIndex { isEditing = false }
        selectedIndex = index
    }

    func beginEditing(_ index: Int? = nil) {
        if let index { select(index) }
        guard variants.indices.contains(selectedIndex), !variants[selectedIndex].isStreaming else { return }
        isEditing = true
    }

    func endEditing() {
        isEditing = false
        panel.clearFocus()
    }

    func setEditedText(_ text: String) {
        guard variants.indices.contains(selectedIndex) else { return }
        variants[selectedIndex].text = text
        variants[selectedIndex].edited = true
    }

    // MARK: - Output

    func replace() {
        let text = currentText
        guard !text.isEmpty else { log.notice("replace: empty text, ignored"); return }
        log.notice("replace: \(text.count) chars, editing=\(self.isEditing)")
        let cap = capture
        let anchor = panel.currentFrame
        History.shared.add(original: original, result: text, appName: sourceAppName)
        hide(animated: false)   // the panel must give up key focus before we type into the source app
        Task {
            let outcome = await TextInsert.replace(text, in: cap)
            Toast.show(outcome == .replaced ? "Replaced" : "Copied", symbol: outcome == .replaced ? "checkmark" : "doc.on.doc", near: anchor)
        }
    }

    func copy(_ index: Int? = nil) {
        if let index { select(index) }
        let text = currentText
        guard !text.isEmpty else { return }
        TextInsert.copy(text)
        History.shared.add(original: original, result: text, appName: sourceAppName)
        let anchor = panel.currentFrame
        hide()
        Toast.show("Copied", symbol: "doc.on.doc", near: anchor)
    }

    // MARK: - Keyboard

    /// Returns true when the key was consumed.
    func handleKey(_ event: NSEvent, inTextField: Bool) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let cmd = flags.contains(.command)
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        log.notice("key: code=\(event.keyCode) chars=\(key, privacy: .public) cmd=\(cmd) inTextField=\(inTextField) editing=\(self.isEditing)")

        switch event.keyCode {
        case 53: // esc
            if isEditing { endEditing(); return true }
            if inTextField, !instruction.isEmpty { instruction = ""; return true }
            hide(); return true
        case 36, 76: // return / enter
            if cmd { replace(); return true }
            if isEditing { return false }                       // newline inside the editor
            if inTextField, !instruction.trimmingCharacters(in: .whitespaces).isEmpty {
                submitInstruction(); return true                // Return in a non-empty instruction box
            }
            replace(); return true                              // otherwise Return always replaces
        
        default:
            break
        }

        if cmd {
            switch key {
            case "c" where !inTextField: copy(); return true
            case "r": runAll(); return true
            case "e": beginEditing(); return true
            case "d": showDiff.toggle(); return true
            default: return false
            }
        }

        guard !inTextField else { return false }
        switch key {
        case "1", "2", "3", "4", "5":
            select(Int(key)! - 1); return true
        case "e": beginEditing(); return true
        case "r": regenerate(selectedIndex); return true
        case "d": showDiff.toggle(); return true
        case "c": copy(); return true
        default: return false
        }
    }
}
