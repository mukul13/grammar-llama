import SwiftUI
import AppKit

/// Click, then press a key combination. Requires at least one modifier.
struct HotKeyRecorder: View {
    @Binding var hotKey: HotKey
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            Text(recording ? "Press keys…" : hotKey.display)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .frame(minWidth: 90)
        }
        .buttonStyle(.bordered)
        .tint(recording ? .accentColor : nil)
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
            if event.keyCode == 53 { stop(); return nil } // esc cancels
            guard !mods.isEmpty else { return nil }
            hotKey = HotKey(keyCode: UInt32(event.keyCode), modifiers: mods)
            stop()
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
