import Foundation

/// Reads and writes FolderLibrary state to keeps.json alongside the photos.
/// Owns the translation between the UUID-based in-memory representation and
/// the stem-based on-disk representation so state survives folder moves.
///
/// Call restore(into:) after openFolder, then startObserving(_:) to begin
/// auto-saving on changes. Call stop() before opening a new folder.
final class LibraryPersistence {
    private let fileURL: URL
    private var isActive = true

    init(folderURL: URL) {
        fileURL = folderURL.appendingPathComponent("keeps.json")
    }

    /// Stops auto-saving. Call before creating a new instance for a new folder.
    func stop() {
        isActive = false
    }

    /// Restores saved passes into the library. Falls back to a fresh single pass
    /// if no saved state exists. Call immediately after openFolder.
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
            FolderLibrary.Pass(
                picks: Set(savedPass.picks.compactMap { idByStem[$0] }),
                rejects: Set(savedPass.rejects.compactMap { idByStem[$0] })
            )
        }
        library.applyRestoredPasses(passes, currentPassIndex: max(0, passes.count - 1))
    }

    /// Begins observing the library and saving to disk whenever pass state changes.
    @MainActor
    func startObserving(_ library: FolderLibrary) {
        withObservationTracking {
            _ = library.passes
        } onChange: {
            Task { @MainActor in
                guard self.isActive else { return }
                self.save(library)
                self.startObserving(library)
            }
        }
    }

    @MainActor
    private func save(_ library: FolderLibrary) {
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
        let data = try? encoder.encode(state)
        try? data?.write(to: fileURL)
    }
}
