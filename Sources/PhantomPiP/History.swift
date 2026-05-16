import Foundation

struct HistoryEntry: Codable {
    var url: String
    var title: String?
    var lastWatched: Date

    /// What the menu shows: the page title if we captured one, else a
    /// tidied URL.
    var displayTitle: String {
        if let title, !title.trimmingCharacters(in: .whitespaces).isEmpty {
            return title.count > 64 ? String(title.prefix(63)) + "…" : title
        }
        var s = url
        for prefix in ["https://", "http://", "www."] {
            if s.hasPrefix(prefix) { s.removeFirst(prefix.count) }
        }
        return s.count > 64 ? String(s.prefix(63)) + "…" : s
    }
}

/// Persists watched videos to JSON under Application Support so the list
/// survives quitting. A flat file is used rather than UserDefaults because a
/// non-bundled `swift run` binary has no stable preferences domain.
final class HistoryStore {
    private(set) var items: [HistoryEntry] = []
    private let fileURL: URL
    private let maxItems: Int

    /// Default store: `~/Library/Application Support/PhantomPiP/`.
    convenience init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.init(directory: base.appendingPathComponent("PhantomPiP", isDirectory: true))
    }

    /// Designated init with an injectable directory (used by tests so the
    /// real history is never touched) and a configurable cap.
    init(directory: URL, maxItems: Int = 50) {
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("history.json")
        self.maxItems = maxItems
        loadFromDisk()
    }

    /// Record a watch. Re-watching an existing URL moves it to the top
    /// instead of duplicating, and keeps any title already captured.
    func add(url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let idx = items.firstIndex(where: { $0.url == trimmed }) {
            var entry = items.remove(at: idx)
            entry.lastWatched = Date()
            items.insert(entry, at: 0)
        } else {
            items.insert(HistoryEntry(url: trimmed, title: nil,
                                      lastWatched: Date()), at: 0)
        }
        if items.count > maxItems { items = Array(items.prefix(maxItems)) }
        save()
    }

    func setTitle(for url: String, title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty,
              let idx = items.firstIndex(where: { $0.url == url }),
              items[idx].title != t
        else { return }
        items[idx].title = t
        save()
    }

    func clear() {
        items = []
        save()
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else { return }
        items = decoded.sorted { $0.lastWatched > $1.lastWatched }
    }

    private func save() {
        items.sort { $0.lastWatched > $1.lastWatched }
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
