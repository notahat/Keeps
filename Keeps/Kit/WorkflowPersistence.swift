import Foundation
import Observation

/// Saves and restores a workflow's Codable state to keeps.json in the photo
/// folder. The JSON envelope records which workflow wrote the file, so state
/// left behind by a different workflow experiment is detected and ignored
/// rather than mis-decoded. Does not manage folder access — FolderSession
/// owns the security scope.
///
/// Call restore() after creating the workflow's state, then startObserving
/// to begin auto-saving on changes. Call stop() to halt auto-saving when the
/// workflow's view goes away, such as when a different folder is opened.
final class WorkflowPersistence<State: Codable> {
    private let fileURL: URL
    private let workflowName: String
    private var isActive = true

    /// The on-disk wrapper that pairs the state with the workflow it
    /// belongs to.
    private struct Envelope: Codable {
        var workflow: String
        var state: State
    }

    init(folderURL: URL, workflowName: String) {
        fileURL = folderURL.appendingPathComponent("keeps.json")
        self.workflowName = workflowName
    }

    /// Returns the saved state, or nil when the file is missing, unreadable,
    /// or was written by a different workflow.
    func restore() -> State? {
        guard let data = try? Data(contentsOf: fileURL),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.workflow == workflowName
        else { return nil }
        return envelope.state
    }

    /// Writes the state to keeps.json. Throws if the data cannot be encoded
    /// or written; callers are expected to surface the failure rather than
    /// swallow it, so the user knows their marks are at risk.
    func save(_ state: State) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Envelope(workflow: workflowName, state: state))
        try data.write(to: fileURL)
    }

    /// Stops auto-saving.
    func stop() {
        isActive = false
    }

    /// Begins observing whatever observable state `read` touches, writing a
    /// fresh snapshot to disk whenever it changes. Save failures are passed
    /// to onSaveError so the UI can alert the user.
    @MainActor
    func startObserving(
        read: @escaping @MainActor () -> Void,
        snapshot: @escaping @MainActor () -> State,
        onSaveError: @escaping @MainActor (Error) -> Void
    ) {
        withObservationTracking {
            read()
        } onChange: {
            Task { @MainActor in
                guard self.isActive else { return }
                do {
                    try self.save(snapshot())
                } catch {
                    onSaveError(error)
                }
                self.startObserving(read: read, snapshot: snapshot, onSaveError: onSaveError)
            }
        }
    }
}
