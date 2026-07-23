import Foundation

/// Reads and writes FolderLibrary state to keeps.json alongside the photos.
/// Owns the translation between the UUID-based in-memory representation and
/// the stem-based on-disk representation so state survives folder moves.
///
/// Also owns the security-scoped resource access for the folder — access begins
/// on init and ends on deinit, so the folder remains accessible as long as this
/// object is alive.
///
/// Call restore(into:) after openFolder, then startObserving(_:) to begin
/// auto-saving on changes. Call stop() to halt auto-saving before opening a
/// new folder.
///
/// To add new persistent state: add a field to LibraryState (and its JSON
/// coding), read it in restore(into:), and write it in save(_:). The
/// withObservationTracking in startObserving(_:) already watches the relevant
/// FolderLibrary properties — just make sure the new state is part of passes
/// or groups, or add it to the tracking block.
final class LibraryPersistence {
    private let folderURL: URL
    private let fileURL: URL
    private var isActive = true

    init(folderURL: URL) {
        self.folderURL = folderURL
        fileURL = folderURL.appendingPathComponent("keeps.json")
        _ = folderURL.startAccessingSecurityScopedResource()
    }

    deinit {
        folderURL.stopAccessingSecurityScopedResource()
    }

    /// Stops auto-saving. Call before creating a new instance for a new folder.
    func stop() {
        isActive = false
    }

    /// Restores saved passes into the library. Falls back to a fresh single
    /// pass if no saved state exists. Call immediately after openFolder.
    func restore(into library: FolderLibrary) {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? JSONDecoder().decode(LibraryState.self, from: data),
              !state.passes.isEmpty
        else {
            library.initializeFreshPasses()
            return
        }

        let idByStem = Dictionary(uniqueKeysWithValues: library.items.map { ($0.stem, $0.id) })
        let passes = state.passes.map { savedPass in
            PassStore.Pass(
                picks: Set(savedPass.picks.compactMap { idByStem[$0] }),
                rejects: Set(savedPass.rejects.compactMap { idByStem[$0] })
            )
        }
        library.applyRestoredPasses(passes, currentPassIndex: max(0, passes.count - 1))
    }

    /// Begins observing the library and saving to disk whenever pass state
    /// changes. Save failures are reported to the library so the UI can
    /// alert the user.
    @MainActor
    func startObserving(_ library: FolderLibrary) {
        withObservationTracking {
            _ = library.passes
        } onChange: {
            Task { @MainActor in
                guard self.isActive else { return }
                do {
                    try self.save(library)
                } catch {
                    library.recordSaveError(error)
                }
                self.startObserving(library)
            }
        }
    }

    /// Writes the library's pass state to keeps.json. Throws if the data
    /// cannot be encoded or written; callers are expected to surface the
    /// failure rather than swallow it, so the user knows their marks are at risk.
    @MainActor
    func save(_ library: FolderLibrary) throws {
        let stemByID = Dictionary(uniqueKeysWithValues: library.items.map { ($0.id, $0.stem) })
        let state = LibraryState(
            passes: library.passes.map { pass in
                LibraryState.Pass(
                    picks: pass.picks.compactMap { stemByID[$0] }.sorted(),
                    rejects: pass.rejects.compactMap { stemByID[$0] }.sorted()
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: fileURL)
    }
}
