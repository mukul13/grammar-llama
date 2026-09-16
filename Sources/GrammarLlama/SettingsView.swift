import SwiftUI
import ServiceManagement

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings().tabItem { Label("General", systemImage: "gear") }
            ModelSettings().tabItem { Label("Model", systemImage: "cpu") }
            PromptSettings().tabItem { Label("Prompt", systemImage: "text.quote") }
            HistorySettings().tabItem { Label("History", systemImage: "clock") }
        }
        .frame(width: 520, height: 400)
        .tint(Theme.accent)
        .onAppear { NSApp.activate(ignoringOtherApps: true) }
    }
}

struct GeneralSettings: View {
    @State private var hotKey = Prefs.hotKey
    @State private var variantCount = Prefs.variantCount
    @State private var alwaysPaste = Prefs.alwaysPaste
    @State private var showDiff = Prefs.showDiffByDefault
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var trusted = Permissions.isTrusted
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    HotKeyRecorder(hotKey: $hotKey)
                } label: {
                    Text("Shortcut")
                    Text("Click to record a new combination.").font(.caption).foregroundStyle(.secondary)
                }
                Stepper(value: $variantCount, in: 1...5) {
                    Text("Variants: \(variantCount)")
                    Text("How many rewrites to show at once.").font(.caption).foregroundStyle(.secondary)
                }
                Toggle("Show changes by default", isOn: $showDiff)
                Toggle(isOn: $alwaysPaste) {
                    Text("Always paste to replace")
                    Text("Skips the Accessibility insert. Use if an app ignores Replace.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
                LabeledContent("Accessibility") {
                    HStack {
                        Image(systemName: trusted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(trusted ? .green : .red)
                        Text(trusted ? "Granted" : "Not granted")
                        if !trusted { Button("Grant…") { Permissions.requestAccessibility() } }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: hotKey) { _, v in Prefs.hotKey = v; HotKeyCenter.shared.register(v) }
        .onChange(of: variantCount) { _, v in Prefs.variantCount = v }
        .onChange(of: alwaysPaste) { _, v in Prefs.alwaysPaste = v }
        .onChange(of: showDiff) { _, v in Prefs.showDiffByDefault = v }
        .onChange(of: launchAtLogin) { _, v in
            do {
                if v { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                loginError = nil
            } catch {
                loginError = "Launch at login needs the bundled Grammar Llama.app: \(error.localizedDescription)"
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            trusted = Permissions.isTrusted
        }
    }
}

struct ModelSettings: View {
    @State private var provider = Prefs.provider
    @State private var anthropicKey = Keychain.anthropicKey ?? ""
    @State private var openAIKey = Keychain.openAIKey ?? ""
    @State private var model = Prefs.model
    @State private var openAIModel = Prefs.openAIModel
    @State private var effort = Prefs.effort
    @State private var saved = true

    var body: some View {
        Form {
            Section {
                Picker("Provider", selection: $provider) {
                    ForEach(Provider.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section(provider == .anthropic ? "Anthropic" : "OpenAI") {
                if provider == .anthropic {
                    SecureField("API key", text: $anthropicKey).onSubmit(save)
                    Picker("Model", selection: $model) {
                        ForEach(Prefs.models, id: \.id) { Text($0.name).tag($0.id) }
                    }
                    Picker("Effort", selection: $effort) {
                        Text("Low (fastest)").tag("low")
                        Text("Medium").tag("medium")
                        Text("High").tag("high")
                    }
                    .disabled(model.hasPrefix("claude-haiku"))
                    Text("Low effort is the sweet spot for rewrites: near-instant and accurate. Raise it only if results feel sloppy.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    SecureField("API key", text: $openAIKey).onSubmit(save)
                    TextField("Model", text: $openAIModel)
                    Text("Any chat model name from platform.openai.com works here. gpt-4o-mini is fast and cheap for rewrites.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Text("Keys are stored in your login Keychain and sent only to the provider you chose.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(saved ? "Saved" : "Save") { save() }.disabled(saved)
                }
                Link("Get a key", destination: provider.consoleURL).font(.caption)
            }
        }
        .formStyle(.grouped)
        .onChange(of: provider) { _, v in Prefs.provider = v }
        .onChange(of: model) { _, v in Prefs.model = v }
        .onChange(of: effort) { _, v in Prefs.effort = v }
        .onChange(of: openAIModel) { _, v in Prefs.openAIModel = v.trimmingCharacters(in: .whitespaces) }
        .onChange(of: anthropicKey) { _, _ in saved = false }
        .onChange(of: openAIKey) { _, _ in saved = false }
    }

    private func save() {
        Keychain.anthropicKey = anthropicKey.trimmingCharacters(in: .whitespacesAndNewlines)
        Keychain.openAIKey = openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        saved = true
    }
}

struct PromptSettings: View {
    @State private var prompt = Prefs.systemPrompt
    @State private var tweaks = Prefs.customTweaks.joined(separator: ", ")

    var body: some View {
        Form {
            Section("Default instructions") {
                TextEditor(text: $prompt)
                    .font(.system(size: 12))
                    .frame(minHeight: 150)
                HStack {
                    Button("Reset to default") { prompt = Prefs.defaultSystemPrompt }
                    Spacer()
                    Button("Save") { Prefs.systemPrompt = prompt }
                }
            }
            Section("Quick tweak chips") {
                TextField("Comma separated", text: $tweaks)
                    .onSubmit(saveTweaks)
                Text("Shown under the instruction box. One click applies the tweak to all variants.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Save chips") { saveTweaks() }
            }
        }
        .formStyle(.grouped)
    }

    private func saveTweaks() {
        Prefs.customTweaks = tweaks.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

struct HistorySettings: View {
    @ObservedObject var history = History.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if history.entries.isEmpty {
                Spacer()
                Text("Rewrites you replace or copy show up here.").foregroundStyle(.secondary).frame(maxWidth: .infinity)
                Spacer()
            } else {
                List(history.entries) { e in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(e.appName.isEmpty ? "Unknown app" : e.appName).font(.caption.weight(.semibold))
                            Text(e.date, style: .relative).font(.caption).foregroundStyle(.tertiary)
                            Spacer()
                            Button("Copy") { TextInsert.copy(e.result) }.controlSize(.mini)
                        }
                        Text(e.result).font(.system(size: 12)).lineLimit(3)
                        Text(e.original).font(.system(size: 11)).foregroundStyle(.tertiary).lineLimit(1)
                    }
                    .padding(.vertical, 2)
                }
                HStack { Spacer(); Button("Clear history") { history.clear() } }
            }
        }
        .padding()
    }
}
