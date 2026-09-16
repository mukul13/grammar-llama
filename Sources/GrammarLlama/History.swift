import Foundation

struct HistoryEntry: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var original: String
    var result: String
    var appName: String
}

@MainActor
final class History: ObservableObject {
    static let shared = History()
    @Published private(set) var entries: [HistoryEntry] = []

    private let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Grammar Llama", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }()

    private init() {
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) {
            entries = decoded
        }
    }

    func add(original: String, result: String, appName: String) {
        entries.insert(HistoryEntry(original: original, result: result, appName: appName), at: 0)
        if entries.count > 50 { entries.removeLast(entries.count - 50) }
        save()
    }

    func clear() {
        entries = []
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
