import Foundation
import Observation

/// Saves and restores a workflow's Codable state to keeps.json in the photo
/// folder. The file holds the state and the name of the workflow that wrote
/// it, so state left behind by a different workflow experiment is detected
/// and ignored rather than mis-decoded. Saving replaces the whole file. Does
/// not manage sandbox access to the folder.
///
/// Call restore() after creating the workflow's state, then startObserving
/// to begin auto-saving on changes. Call stop() to halt auto-saving when the
/// workflow's view goes away, such as when its window closes.
final class WorkflowPersistence<State: Codable> {
    /// What keeps.json holds: the state, and which workflow wrote it.
    private struct Contents: Codable {
        let workflow: String
        let state: State
    }

    /// Just the workflow name, so it can be checked before decoding the
    /// state.
    private struct Header: Decodable {
        let workflow: String
    }

    private let fileURL: URL
    private let workflowName: String
    private var isActive = true

    init(folderURL: URL, workflowName: String) {
        fileURL = folderURL.appendingPathComponent("keeps.json")
        self.workflowName = workflowName
    }

    /// Returns the saved state, or nil when the file is missing, unreadable,
    /// or was written by a different workflow.
    func restore() -> State? {
        let decoder = JSONDecoder()
        guard let data = try? Data(contentsOf: fileURL),
              (try? decoder.decode(Header.self, from: data))?.workflow == workflowName
        else { return nil }
        return try? decoder.decode(Contents.self, from: data).state
    }

    /// Writes the state to keeps.json. Throws if the data cannot be encoded
    /// or written; callers are expected to surface the failure rather than
    /// swallow it, so the user knows their work is at risk.
    func save(_ state: State) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Contents(workflow: workflowName, state: state))
        try data.write(to: fileURL)
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
        snapshot: @escaping @MainActor () -> State,
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
