import Foundation

enum Provider: String, CaseIterable, Identifiable {
    case anthropic, openai
    var id: String { rawValue }
    var name: String { self == .anthropic ? "Anthropic (Claude)" : "OpenAI (ChatGPT)" }
    var keyPlaceholder: String { self == .anthropic ? "sk-ant-…" : "sk-…" }
    var consoleURL: URL {
        URL(string: self == .anthropic ? "https://console.anthropic.com/settings/keys" : "https://platform.openai.com/api-keys")!
    }
}

protocol LLMClient {
    func stream(system: String, user: String) -> AsyncThrowingStream<String, Error>
}

enum LLM {
    /// Builds the client for the provider chosen in Settings, or nil when its key is missing.
    static var fromSettings: LLMClient? {
        switch Prefs.provider {
        case .anthropic:
            guard let key = Keychain.anthropicKey else { return nil }
            return ClaudeClient(apiKey: key, model: Prefs.model, effort: Prefs.effort)
        case .openai:
            guard let key = Keychain.openAIKey else { return nil }
            return OpenAIClient(apiKey: key, model: Prefs.openAIModel)
        }
    }

    static var hasKeyForCurrentProvider: Bool {
        Prefs.provider == .anthropic ? Keychain.anthropicKey != nil : Keychain.openAIKey != nil
    }
}

/// Streaming client for OpenAI's Chat Completions endpoint.
struct OpenAIClient: LLMClient {
    var apiKey: String
    var model: String

    func stream(system: String, user: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await run(system: system, user: user) { continuation.yield($0) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(system: String, user: String, onDelta: (String) -> Void) async throws {
        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
        ]
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 60

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            var raw = ""
            for try await line in bytes.lines { raw += line }
            let message = (try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
                .flatMap { $0["error"] as? [String: Any] }
                .flatMap { $0["message"] as? String } ?? raw
            throw ClaudeError.http(status, message)
        }

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let err = obj["error"] as? [String: Any] {
                throw ClaudeError.transport(err["message"] as? String ?? "stream error")
            }
            if let choices = obj["choices"] as? [[String: Any]],
               let delta = choices.first?["delta"] as? [String: Any],
               let text = delta["content"] as? String {
                onDelta(text)
            }
        }
    }
}
