import Foundation
import Observation

/// Saves and restores a workflow's Codable state to keeps.json in the photo
/// folder, under the "state" entry. The "workflow" entry records which
/// workflow wrote it, so state left behind by a different workflow
/// experiment is detected and ignored rather than mis-decoded. Other entries
/// in the file are left alone. Does not manage folder access — FolderSession
/// owns the security scope.
///
/// Call restore() after creating the workflow's state, then startObserving
/// to begin auto-saving on changes. Call stop() to halt auto-saving when the
/// workflow's view goes away, such as when its window closes.
final class WorkflowPersistence<State: Codable> {
    private let file: KeepsFile
    private let workflowName: String
    private var isActive = true

    init(folderURL: URL, workflowName: String) {
        file = KeepsFile(folderURL: folderURL)
        self.workflowName = workflowName
    }

    /// Returns the saved state, or nil when the file is missing, unreadable,
    /// or was written by a different workflow.
    func restore() -> State? {
        guard file.read(String.self, forKey: "workflow") == workflowName else { return nil }
        return file.read(State.self, forKey: "state")
    }

    /// Writes the state to keeps.json. Throws if the data cannot be encoded
    /// or written; callers are expected to surface the failure rather than
    /// swallow it, so the user knows their marks are at risk.
    func save(_ state: State) throws {
        try file.write(["workflow": workflowName, "state": state])
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
