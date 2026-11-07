import Foundation
import Observation

/// Saves and restores a folder's grouping to keeps.json in the photo folder.
/// The file holds the saved grouping and the name of its format, so a file
/// in a format this version of Keeps doesn't know is refused rather than
/// mis-decoded. Saving replaces the whole file.
///
/// Call restore() before showing the grouping, then startAutoSaving to save
/// on every change. If restore() throws, don't auto-save: the file holds
/// work that would be lost by writing over it. Call stopAutoSaving() when
/// the folder's view goes away, such as when its window closes.
///
/// KeepsFile doesn't manage sandbox access to the folder, and doesn't
/// convert between the saved form and the live grouping; Grouping does that.
final class KeepsFile {
    /// Thrown when keeps.json is there but can't be restored. Its message
    /// tells the user what went wrong and that changes won't be saved.
    nonisolated struct UnreadableFileError: LocalizedError {
        /// The name of the folder holding the keeps.json, for the message.
        let folderName: String

        /// Why the file couldn't be restored.
        let underlyingError: Error

        var errorDescription: String? {
            "Keeps couldn't read the keeps.json file in “\(folderName)”."
        }

        var recoverySuggestion: String? {
            "\(underlyingError.localizedDescription) Changes to this folder won't be saved, so the file is left as it is."
        }
    }

    /// Thrown inside UnreadableFileError when keeps.json names a format this
    /// version doesn't know, such as one written by a later version.
    nonisolated struct UnknownFormatError: LocalizedError {
        /// The format name the file gives.
        let formatName: String

        var errorDescription: String? {
            "It's in a format this version of Keeps doesn't know (“\(formatName)”)."
        }
    }

    /// What keeps.json holds: the saved grouping, and the name of its
    /// format. The format name's key is "workflow", the name it was first
    /// written under, so existing files keep loading.
    private struct Contents: Codable {
        let formatName: String
        let state: SavedGrouping

        private enum CodingKeys: String, CodingKey {
            case formatName = "workflow"
            case state
        }
    }

    /// Just the format name, so it can be checked before decoding the rest.
    private struct Header: Decodable {
        let formatName: String

        private enum CodingKeys: String, CodingKey {
            case formatName = "workflow"
        }
    }

    /// Where keeps.json is, whether or not it exists.
    private let fileURL: URL

    /// Whether stopAutoSaving() has been called, after which nothing more is
    /// saved.
    private var isStopped = false

    /// Make a KeepsFile for the keeps.json in a photo folder, without
    /// reading or writing it.
    init(folderURL: URL) {
        fileURL = folderURL.appendingPathComponent("keeps.json")
    }

    /// Return the saved grouping, or nil when there's no keeps.json. Throw
    /// UnreadableFileError when there is one but it can't be read, isn't
    /// valid, or is in a format this version of Keeps doesn't know.
    func restore() throws -> SavedGrouping? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            return try Self.decodeGrouping(from: Data(contentsOf: fileURL))
        } catch {
            let folderName = fileURL.deletingLastPathComponent().lastPathComponent
            throw UnreadableFileError(folderName: folderName, underlyingError: error)
        }
    }

    /// Decode the saved grouping from the file's contents, checking the
    /// format name first.
    private static func decodeGrouping(from data: Data) throws -> SavedGrouping {
        let decoder = JSONDecoder()
        let formatName = try decoder.decode(Header.self, from: data).formatName
        guard formatName == SavedGrouping.originalFormatName else {
            throw UnknownFormatError(formatName: formatName)
        }
        return try decoder.decode(Contents.self, from: data).state
    }

    /// Write the grouping to keeps.json. Throw if the grouping cannot be
    /// encoded or written; callers are expected to surface the failure
    /// rather than swallow it, so the user knows their work is at risk.
    func save(_ savedGrouping: SavedGrouping) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let contents = Contents(formatName: SavedGrouping.originalFormatName, state: savedGrouping)
        try encoder.encode(contents).write(to: fileURL)
    }

    /// Stop auto-saving, so nothing more is saved, including a change already
    /// waiting to be saved.
    func stopAutoSaving() {
        isStopped = true
    }

    /// Begin observing whatever observable state `snapshot` reads, writing
    /// a fresh snapshot to disk whenever it changes. Save failures are passed
    /// to onSaveError so the UI can alert the user.
    ///
    /// withObservationTracking reports only the first change, and reports it
    /// before the new value is stored. So the save waits in a Task until the
    /// change has landed, or it would save the old value, and then observes
    /// again, or only the first change would ever be saved.
    @MainActor
    func startAutoSaving(
        snapshot: @escaping @MainActor () -> SavedGrouping,
        onSaveError: @escaping @MainActor (Error) -> Void
    ) {
        withObservationTracking {
            _ = snapshot()
        } onChange: {
            Task { @MainActor in
                guard !self.isStopped else { return }
                do {
                    try self.save(snapshot())
                } catch {
                    onSaveError(error)
                }
                self.startAutoSaving(snapshot: snapshot, onSaveError: onSaveError)
            }
        }
    }
}
