import Foundation

enum ClaudeError: LocalizedError {
    case missingKey
    case http(Int, String)
    case refused(String?)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "Add an API key in Settings (Anthropic or OpenAI)."
        case .http(let code, let msg): return "API error \(code): \(msg)"
        case .refused(let why): return "The model declined this request" + (why.map { ": \($0)" } ?? ".")
        case .transport(let msg): return msg
        }
    }
}

/// Minimal streaming client for POST /v1/messages over raw HTTP (no official Swift SDK).
struct ClaudeClient: LLMClient {
    var apiKey: String
    var model: String
    var effort: String

    private var supportsEffort: Bool { !model.hasPrefix("claude-haiku") }
    private var supportsFallbacks: Bool { model.hasPrefix("claude-opus-5") || model.hasPrefix("claude-fable") }

    /// Streams text deltas for a single user message.
    func stream(system: String, user: String) -> AsyncThrowingStream<String, Error> { stream(system: system, user: user, maxTokens: 8192) }

    func stream(system: String, user: String, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await run(system: system, user: user, maxTokens: maxTokens) { continuation.yield($0) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(system: String, user: String, maxTokens: Int, onDelta: (String) -> Void) async throws {
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "stream": true,
            "system": system,
            "messages": [["role": "user", "content": user]],
        ]
        if supportsEffort { body["output_config"] = ["effort": effort] }
        if supportsFallbacks { body["fallbacks"] = "default" }

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        if supportsFallbacks {
            req.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        }
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
            guard let data = payload.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = obj["type"] as? String else { continue }

            switch type {
            case "content_block_delta":
                if let delta = obj["delta"] as? [String: Any],
                   delta["type"] as? String == "text_delta",
                   let text = delta["text"] as? String {
                    onDelta(text)
                }
            case "message_delta":
                if let delta = obj["delta"] as? [String: Any],
                   delta["stop_reason"] as? String == "refusal" {
                    let why = (delta["stop_details"] as? [String: Any])?["explanation"] as? String
                    throw ClaudeError.refused(why)
                }
            case "error":
                let msg = (obj["error"] as? [String: Any])?["message"] as? String ?? "stream error"
                throw ClaudeError.transport(msg)
            default:
                break
            }
        }
    }
}
