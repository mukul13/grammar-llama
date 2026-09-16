import SwiftUI

@main
struct GrammarLlamaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            Text("🦙")
        }
        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        HotKeyCenter.shared.onPress = { AppState.shared.trigger() }
        HotKeyCenter.shared.registerFromSettings()
        log.notice("launched; accessibility trusted=\(Permissions.isTrusted) apiKey=\(LLM.hasKeyForCurrentProvider) provider=\(Prefs.provider.rawValue, privacy: .public)")
        if !Permissions.isTrusted || !LLM.hasKeyForCurrentProvider {
            Onboarding.show()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
