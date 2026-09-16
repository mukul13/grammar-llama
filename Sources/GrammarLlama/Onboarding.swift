import SwiftUI
import AppKit

@MainActor
enum Onboarding {
    private static var window: NSWindow?

    static func show() {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let w = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 440, height: 420),
                         styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: OnboardingView(close: { w.close() }))
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
    }
}

struct OnboardingView: View {
    var close: () -> Void
    @State private var trusted = Permissions.isTrusted
    @State private var provider = Prefs.provider
    @State private var apiKey = ""
    @State private var keySaved = LLM.hasKeyForCurrentProvider

    private var ready: Bool { trusted && keySaved }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Theme.gradient)
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(.white.opacity(0.18)))
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable().scaledToFit()
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Grammar Llama").font(.system(size: 20, weight: .bold))
                    Text("Select text anywhere. Press \(Prefs.hotKey.display). Sound right.")
                        .foregroundStyle(.secondary)
                }
            }

            step(number: 1, done: trusted, title: "Allow Accessibility access",
                 detail: "Grammar Llama reads the text you select and puts the rewrite back. macOS calls this Accessibility. Nothing is recorded.") {
                VStack(alignment: .leading, spacing: 6) {
                    Button(trusted ? "Granted" : "Open System Settings…") { Permissions.requestAccessibility() }
                        .disabled(trusted)
                    if !trusted {
                        Text("In System Settings → Privacy & Security → Accessibility, turn on Grammar Llama. If it is already listed, switch it off and on again, or remove it with − and add Grammar Llama.app with +.")
                            .font(.caption).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            step(number: 2, done: keySaved, title: "Add an API key",
                 detail: "Claude or ChatGPT, your choice. Stored in your Keychain. Text goes only to that provider, and only when you press the shortcut.") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Provider", selection: $provider) {
                        ForEach(Provider.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    .onChange(of: provider) { _, v in
                        Prefs.provider = v
                        apiKey = ""
                        keySaved = LLM.hasKeyForCurrentProvider
                    }
                    HStack {
                        SecureField(provider.keyPlaceholder, text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: apiKey) { _, _ in keySaved = false }
                        Button("Save") {
                            let k = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            if provider == .anthropic { Keychain.anthropicKey = k } else { Keychain.openAIKey = k }
                            keySaved = LLM.hasKeyForCurrentProvider
                        }
                        .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }

            Spacer()
            HStack {
                Text("Grammar Llama lives in the menu bar as 🦙. There is no Dock icon.")
                    .font(.caption).foregroundStyle(.tertiary)
                Spacer()
                if ready {
                    Button("Done") { close() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(28)
        .frame(width: 440, height: 420)
        .tint(Theme.accent)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            trusted = Permissions.isTrusted
        }
    }

    @ViewBuilder
    private func step<Content: View>(number: Int, done: Bool, title: String, detail: String,
                                     @ViewBuilder control: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(done ? Color.green : Color.primary.opacity(0.1)).frame(width: 24, height: 24)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                } else {
                    Text("\(number)").font(.system(size: 12, weight: .semibold))
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                control()
            }
        }
    }
}
