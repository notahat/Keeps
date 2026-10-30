import Foundation

/// The keeps.json file in a photo folder: a JSON object of named entries,
/// each written and read independently, so writing one never overwrites the
/// others. Knows nothing about what the entries mean.
nonisolated struct KeepsFile {
    let fileURL: URL

    init(folderURL: URL) {
        fileURL = folderURL.appendingPathComponent("keeps.json")
    }

    /// Returns the entry saved under `key`, or nil when the file is missing
    /// or unreadable, or the entry is absent or isn't a `Value`.
    func read<Value: Decodable>(_: Value.Type, forKey key: String) -> Value? {
        guard let entry = readEntries()[key],
              let data = try? JSONSerialization.data(withJSONObject: entry, options: .fragmentsAllowed)
        else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    /// Writes the entries into the file, replacing any with the same keys and
    /// keeping the rest. Throws if an entry can't be encoded or the file
    /// can't be written.
    func write(_ newEntries: [String: any Encodable]) throws {
        var entries = readEntries()
        for (key, value) in newEntries {
            let data = try JSONEncoder().encode(value)
            entries[key] = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
        }
        let data = try JSONSerialization.data(
            withJSONObject: entries,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: fileURL)
    }

    /// The entries currently in the file. A missing or unreadable file has
    /// none, so the next write starts it afresh.
    private func readEntries() -> [String: Any] {
        guard let data = try? Data(contentsOf: fileURL),
              let object = try? JSONSerialization.jsonObject(with: data),
              let entries = object as? [String: Any]
        else { return [:] }
        return entries
    }
}
