import Foundation

/// Stores the per-photo marks across a sequence of review passes and tracks
/// which pass is currently being viewed. Pure data store — does not know about
/// filtering, selection, or persistence. Methods that need the full set of
/// photos take it as an items parameter, since the store does not own that
/// list.
///
/// Each pass holds its own picks and rejects. The photos visible in pass N are
/// all photos not picked or rejected in passes 0..<N, so marks made in earlier
/// passes automatically hide those photos from later ones.
struct PassStore {
    enum Mark: String, Codable { case pick, reject }

    struct Pass {
        var picks: Set<UUID> = []
        var rejects: Set<UUID> = []
    }

    struct PassStats {
        let total: Int
        let picks: Int
        let rejects: Int
    }

    private(set) var passes: [Pass] = []
    private(set) var currentPassIndex: Int = 0

    /// The pass currently being viewed, or nil when no passes exist.
    var currentPass: Pass? {
        passes.isEmpty ? nil : passes[currentPassIndex]
    }

    /// True when the last pass has at least one marked photo, enabling the next pass.
    var canStartNextPass: Bool {
        guard let pass = passes.last else { return false }
        return !pass.picks.isEmpty || !pass.rejects.isEmpty
    }

    /// Returns the mark for a photo in the currently viewed pass, or nil if unmarked.
    func mark(for id: UUID) -> Mark? {
        guard let currentPass else { return nil }
        if currentPass.picks.contains(id) { return .pick }
        if currentPass.rejects.contains(id) { return .reject }
        return nil
    }

    /// Returns the cumulative mark for a photo across all passes. The last
    /// pass to mark the photo wins. Returns nil if never marked.
    func cumulativeMark(for id: UUID) -> Mark? {
        for pass in passes.reversed() {
            if pass.picks.contains(id) { return .pick }
            if pass.rejects.contains(id) { return .reject }
        }
        return nil
    }

    /// The IDs of photos visible in the current pass: every item not picked or
    /// rejected in any earlier pass.
    func currentPassPhotoIDs(items: [PhotoItem]) -> Set<UUID> {
        let previouslyMarked = passes[0 ..< currentPassIndex].reduce(into: Set<UUID>()) {
            $0.formUnion($1.picks)
            $0.formUnion($1.rejects)
        }
        return Set(items.map(\.id)).subtracting(previouslyMarked)
    }

    /// Groups photos by their cumulative mark for sorting into folders.
    func sortPlan(items: [PhotoItem]) -> [Mark?: [PhotoItem]] {
        Dictionary(grouping: items) { cumulativeMark(for: $0.id) }
    }

    /// Pick/reject/total counts for the pass at the given index. Total excludes
    /// photos already marked in earlier passes, since those don't appear in this pass.
    func stats(for index: Int, items: [PhotoItem]) -> PassStats {
        let markedInPreviousPasses = passes[0 ..< index].reduce(into: Set<UUID>()) {
            $0.formUnion($1.picks)
            $0.formUnion($1.rejects)
        }
        return PassStats(
            total: items.filter { !markedInPreviousPasses.contains($0.id) }.count,
            picks: passes[index].picks.count,
            rejects: passes[index].rejects.count
        )
    }

    /// Sets, changes, or clears the mark for a photo in the current pass.
    /// Passing nil unmarks. Pick and reject are mutually exclusive.
    mutating func setMark(_ mark: Mark?, for itemID: UUID) {
        passes[currentPassIndex].picks.remove(itemID)
        passes[currentPassIndex].rejects.remove(itemID)
        if mark == .pick {
            passes[currentPassIndex].picks.insert(itemID)
        } else if mark == .reject {
            passes[currentPassIndex].rejects.insert(itemID)
        }
    }

    /// Appends a new empty pass and selects it.
    mutating func startNextPass() {
        passes.append(Pass())
        currentPassIndex = passes.count - 1
    }

    /// Switches the current pass index without otherwise modifying state.
    mutating func selectPass(_ index: Int) {
        currentPassIndex = index
    }

    /// Sets up a single empty pass. Called when no saved state exists.
    mutating func initializeFresh() {
        passes = [Pass()]
        currentPassIndex = 0
    }

    /// Replaces passes with restored state.
    mutating func applyRestored(passes: [Pass], currentPassIndex: Int) {
        self.passes = passes
        self.currentPassIndex = currentPassIndex
    }

    /// Resets to the initial empty state.
    mutating func reset() {
        passes = []
        currentPassIndex = 0
    }
}
