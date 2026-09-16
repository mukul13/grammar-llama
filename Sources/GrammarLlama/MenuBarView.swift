import SwiftUI

struct MenuBarView: View {
    @ObservedObject private var history = History.shared

    var body: some View {
        Button("Fix Selected Text") { AppState.shared.trigger() }
        Text("Shortcut: \(Prefs.hotKey.display)")
        Divider()
        if !history.entries.isEmpty {
            Menu("Recent") {
                ForEach(history.entries.prefix(8)) { e in
                    Button(String(e.result.prefix(48)).replacingOccurrences(of: "\n", with: " ")) {
                        TextInsert.copy(e.result)
                    }
                }
            }
            Divider()
        }
        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",", modifiers: .command)
        Button("Quit Grammar Llama") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }
}
