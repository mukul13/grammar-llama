import AppKit
import Carbon
import os

let log = Logger(subsystem: "com.sidepanda.GrammarLlama", category: "app")

struct HotKey: Equatable {
    var keyCode: UInt32
    var modifiers: NSEvent.ModifierFlags

    var carbonModifiers: UInt32 {
        var m: UInt32 = 0
        if modifiers.contains(.command) { m |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { m |= UInt32(shiftKey) }
        if modifiers.contains(.option) { m |= UInt32(optionKey) }
        if modifiers.contains(.control) { m |= UInt32(controlKey) }
        return m
    }

    var display: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option) { s += "⌥" }
        if modifiers.contains(.shift) { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + HotKey.keyName(for: keyCode)
    }

    func matches(_ event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        return UInt32(event.keyCode) == keyCode && mods == modifiers
    }

    static func keyName(for code: UInt32) -> String {
        let map: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B",
            12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4",
            22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O",
            32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
            42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space", 50: "`",
            51: "⌫", 53: "⎋", 122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
            123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        return map[code] ?? "Key \(code)"
    }
}

/// Registers a single system-wide hotkey. Primary path is Carbon's RegisterEventHotKey, which works
/// without any permission. If that fails (another app owns the combo), we fall back to a global
/// NSEvent monitor, which needs Accessibility but is otherwise equivalent.
final class HotKeyCenter {
    static let shared = HotKeyCenter()
    var onPress: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var monitor: Any?
    private(set) var current: HotKey?
    private(set) var lastError: String?

    func registerFromSettings() {
        register(Prefs.hotKey)
    }

    func register(_ hotKey: HotKey) {
        unregister()
        current = hotKey
        installHandlerIfNeeded()

        let id = EventHotKeyID(signature: OSType(0x504F4C53), id: 1) // "POLS"
        let status = RegisterEventHotKey(hotKey.keyCode, hotKey.carbonModifiers, id,
                                         GetEventDispatcherTarget(), 0, &hotKeyRef)
        if status == noErr {
            lastError = nil
            log.notice("Registered hotkey \(hotKey.display, privacy: .public) via Carbon")
        } else {
            lastError = status == eventHotKeyExistsErr
                ? "\(hotKey.display) is already used by another app."
                : "Could not register \(hotKey.display) (error \(status))."
            log.error("Carbon registration failed: \(status) — using global monitor fallback")
            hotKeyRef = nil
        }

        // Always install the monitor too. Carbon fires first when it works; the monitor is a
        // safety net for apps that swallow Carbon hotkeys. Debounced so we never fire twice.
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let hk = self.current, hk.matches(event) else { return }
            self.fire()
        }
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
    }

    private var lastFire = Date.distantPast
    fileprivate func fire() {
        DispatchQueue.main.async {
            guard Date().timeIntervalSince(self.lastFire) > 0.25 else { return }
            self.lastFire = Date()
            log.notice("Hotkey fired")
            self.onPress?()
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetEventDispatcherTarget(), { _, _, userData in
            guard let userData else { return noErr }
            Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue().fire()
            return noErr
        }, 1, &spec, selfPtr, &handlerRef)
        if status != noErr { log.error("InstallEventHandler failed: \(status)") }
    }
}
