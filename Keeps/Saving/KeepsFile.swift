import Foundation
import Observation

/// Saves and restores a folder's grouping to keeps.json in the photo folder.
/// The file holds the saved grouping and the name of its format, so a file
/// in a format this doesn't know is ignored rather than mis-decoded. Saving
/// replaces the whole file. Does not manage sandbox access to the folder,
/// and does not convert between the saved form and the live grouping.
///
/// Call restore() before showing the grouping, then startObserving to begin
/// auto-saving on changes. Call stop() to halt auto-saving when the folder's
/// view goes away, such as when its window closes.
final class KeepsFile {
    /// What keeps.json holds: the saved grouping, and the name of its
    /// format. The format name's key is "workflow", the name it was first
    /// written under, so existing files keep loading.
    private struct Contents: Codable {
        let workflow: String
        let state: SavedGrouping
    }

    /// Just the format name, so it can be checked before decoding the rest.
    private struct Header: Decodable {
        let workflow: String
    }

    private let fileURL: URL
    private var isActive = true

    init(folderURL: URL) {
        fileURL = folderURL.appendingPathComponent("keeps.json")
    }

    /// Returns the saved grouping, or nil when the file is missing,
    /// unreadable, or in a format this doesn't know.
    func restore() -> SavedGrouping? {
        let decoder = JSONDecoder()
        guard let data = try? Data(contentsOf: fileURL),
              (try? decoder.decode(Header.self, from: data))?.workflow == SavedGrouping.originalFormatName
        else { return nil }
        return try? decoder.decode(Contents.self, from: data).state
    }

    /// Writes the grouping to keeps.json. Throws if it cannot be encoded or
    /// written; callers are expected to surface the failure rather than
    /// swallow it, so the user knows their work is at risk.
    func save(_ savedGrouping: SavedGrouping) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let contents = Contents(workflow: SavedGrouping.originalFormatName, state: savedGrouping)
        try encoder.encode(contents).write(to: fileURL)
    }

    /// Stops auto-saving.
    func stop() {
        isActive = false
    }

    /// Begins observing whatever observable state `snapshot` reads, writing
    /// a fresh snapshot to disk whenever it changes. Save failures are passed
    /// to onSaveError so the UI can alert the user.
    @MainActor
    func startObserving(
        snapshot: @escaping @MainActor () -> SavedGrouping,
        onSaveError: @escaping @MainActor (Error) -> Void
    ) {
        withObservationTracking {
            _ = snapshot()
        } onChange: {
            Task { @MainActor in
                guard self.isActive else { return }
                do {
                    try self.save(snapshot())
                } catch {
                    onSaveError(error)
                }
                self.startObserving(snapshot: snapshot, onSaveError: onSaveError)
            }
        }
    }
}
