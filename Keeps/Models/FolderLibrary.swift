import Foundation
import Observation
import SwiftUI

/// Owns the photo items for a single open folder. Handles directory scanning,
/// file pairing, selection, view mode, marking, and pass-based review. Does not
/// load image data (that's ImagePipeline's job) or persist state (that's
/// LibraryPersistence's job).
///
/// Each pass stores its own picks and rejects. The photos visible in pass N are
/// all photos not picked or rejected in passes 0..<N, so marks made in earlier
/// passes automatically hide those photos from later ones.
@Observable
class FolderLibrary {
    enum ViewMode { case grid, single }
    enum Mark: String, Codable { case pick, reject }
    enum FilterMode: Equatable, Hashable { case all, picked, rejected, unmarked, group(UUID) }

    struct PassStats {
        let total: Int
        let picks: Int
        let rejects: Int
    }

    struct Pass {
        var picks: Set<UUID> = []
        var rejects: Set<UUID> = []
    }

    /// A named set of photos treated as a visual group, identified by a color bar
    /// on their thumbnails. Stored by item ID in memory; translated to stems for
    /// persistence so groups survive folder moves.
    struct PhotoGroup {
        var id: UUID
        var colorIndex: Int
        var itemIDs: Set<UUID>
    }

    static let groupColors: [Color] = [.orange, .purple, .cyan, .yellow, .pink, .mint]

    private(set) var folderURL: URL?
    private(set) var folderError: Error?
    private(set) var selectedItemID: UUID?
    private(set) var rangeAnchorID: UUID?
    var viewMode: ViewMode = .grid
    var filterMode: FilterMode = .all
    private(set) var items: [PhotoItem] = []
    private(set) var filteredItems: [PhotoItem] = []
    private(set) var passes: [Pass] = []
    private(set) var currentPassIndex: Int = 0
    private(set) var groups: [PhotoGroup] = []

    /// Set each time applyMarkAndAdvance is called, so observers can react to
    /// mark actions regardless of which code path triggered them.
    private(set) var lastMarkEvent: MarkEvent?

    /// Uniquely identifies a single mark application, so observers can detect
    /// repeated applications of the same mark value.
    struct MarkEvent: Equatable {
        let mark: Mark?
        private let token = UUID()

        static func == (lhs: MarkEvent, rhs: MarkEvent) -> Bool {
            lhs.token == rhs.token
        }
    }

    private var currentPass: Pass? {
        passes.isEmpty ? nil : passes[currentPassIndex]
    }

    private var currentPassPhotoIDs: Set<UUID> {
        let previouslyMarked = passes[0 ..< currentPassIndex].reduce(into: Set<UUID>()) {
            $0.formUnion($1.picks)
            $0.formUnion($1.rejects)
        }
        return Set(items.map(\.id)).subtracting(previouslyMarked)
    }

    /// Returns the mark for a photo in the currently viewed pass, or nil if unmarked.
    func mark(for id: UUID) -> Mark? {
        guard let currentPass else { return nil }
        if currentPass.picks.contains(id) { return .pick }
        if currentPass.rejects.contains(id) { return .reject }
        return nil
    }

    /// The index of the selected item within the current filtered list, or nil if the
    /// selected item isn't present in the current filter. Setting this updates the
    /// selected item identity, so the selection follows the item across pass switches.
    var selectedIndex: Int? {
        get {
            guard let id = selectedItemID else { return nil }
            return filteredItems.firstIndex { $0.id == id }
        }
        set {
            selectedItemID = newValue.map { filteredItems[$0].id }
        }
    }

    /// The range of filteredItems indices spanned by the current selection, or nil if
    /// no anchor has been set. Used to render range highlights in the grid.
    var selectionRange: ClosedRange<Int>? {
        guard let selectedIndex,
              let anchorID = rangeAnchorID,
              let anchorIndex = filteredItems.firstIndex(where: { $0.id == anchorID })
        else { return nil }
        return min(anchorIndex, selectedIndex) ... max(anchorIndex, selectedIndex)
    }

    /// Selects the item at the given index and sets it as the range anchor, collapsing
    /// any existing range selection.
    func selectItem(at index: Int) {
        guard filteredItems.indices.contains(index) else { return }
        selectedIndex = index
        rangeAnchorID = filteredItems[index].id
    }

    /// Extends the selection from the current anchor to the given index. If no anchor
    /// is set, uses the current selection as the anchor.
    func extendSelection(to index: Int) {
        guard filteredItems.indices.contains(index) else { return }
        if rangeAnchorID == nil {
            rangeAnchorID = selectedItemID
        }
        selectedIndex = index
    }

    /// True when the last pass has at least one marked photo, enabling the next pass.
    var canStartNextPass: Bool {
        guard let pass = passes.last else { return false }
        return !pass.picks.isEmpty || !pass.rejects.isEmpty
    }

    func setMark(_ mark: Mark?, for item: PhotoItem) {
        passes[currentPassIndex].picks.remove(item.id)
        passes[currentPassIndex].rejects.remove(item.id)
        if mark == .pick {
            passes[currentPassIndex].picks.insert(item.id)
        } else if mark == .reject {
            passes[currentPassIndex].rejects.insert(item.id)
        }
        if filterMode != .all { updateFilteredItems() }
    }

    /// Marks the selected item(s) and advances. When a multi-item range is selected,
    /// marks all items in the range without advancing or collapsing the range, so
    /// the user can easily undo an accidental bulk mark. When a single item is
    /// selected, marks it and moves to the next item.
    func applyMarkAndAdvance(_ mark: Mark?) {
        guard let index = selectedIndex else { return }
        if let range = selectionRange, range.count > 1 {
            let itemsToMark = Array(filteredItems[range])
            for item in itemsToMark {
                setMark(mark, for: item)
            }
            lastMarkEvent = MarkEvent(mark: mark)
        } else {
            setMark(mark, for: filteredItems[index])
            lastMarkEvent = MarkEvent(mark: mark)
            let items = filteredItems
            selectedIndex = items.isEmpty ? nil : min(items.count - 1, index + 1)
            rangeAnchorID = selectedItemID
        }
    }

    /// Creates a new pass. Photos not marked in the current pass will appear in it.
    func startNextPass() {
        passes.append(Pass())
        currentPassIndex = passes.count - 1
        filterMode = .all
        updateFilteredItems()
        selectedIndex = filteredItems.isEmpty ? nil : 0
        rangeAnchorID = nil
    }

    func applyFilter(_ mode: FilterMode) {
        filterMode = mode
        updateFilteredItems()
        selectedIndex = filteredItems.isEmpty ? nil : 0
        rangeAnchorID = nil
    }

    func selectPass(_ index: Int) {
        currentPassIndex = index
        filterMode = .all
        updateFilteredItems()
        selectedIndex = filteredItems.isEmpty ? nil : 0
        rangeAnchorID = nil
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

    /// Groups all photos by their cumulative mark for sorting into folders.
    func sortPlan() -> [Mark?: [PhotoItem]] {
        Dictionary(grouping: items) { cumulativeMark(for: $0.id) }
    }

    /// The items spanned by the current selection range, or an empty array if no
    /// multi-item range is active.
    var selectedRangeItems: [PhotoItem] {
        guard let range = selectionRange else { return [] }
        return Array(filteredItems[range])
    }

    /// The color assigned to the group that contains this photo, or nil if ungrouped.
    func groupColor(for id: UUID) -> Color? {
        guard let group = groups.first(where: { $0.itemIDs.contains(id) }) else { return nil }
        return FolderLibrary.groupColors[group.colorIndex]
    }

    /// True when the currently selected photo belongs to any group.
    var selectedItemIsGrouped: Bool {
        guard let id = selectedItemID else { return false }
        return groups.contains { $0.itemIDs.contains(id) }
    }

    /// True when the grid is filtered to a single group.
    var isGroupFocused: Bool {
        if case .group = filterMode { return true }
        return false
    }

    /// The color of the currently focused group, or nil if not in group focus mode.
    var focusedGroupColor: Color? {
        guard case let .group(groupID) = filterMode,
              let group = groups.first(where: { $0.id == groupID })
        else { return nil }
        return FolderLibrary.groupColors[group.colorIndex]
    }

    /// Focuses the grid on the group containing the selected photo, keeping the
    /// current selection in place.
    func focusSelectedItemGroup() {
        guard let id = selectedItemID,
              let group = groups.first(where: { $0.itemIDs.contains(id) })
        else { return }
        filterMode = .group(group.id)
        updateFilteredItems()
        rangeAnchorID = selectedItemID
    }

    /// Removes the group that contains the currently selected photo. Resets group
    /// focus if the focused group is the one being deleted.
    func ungroupSelectedItem() {
        guard let id = selectedItemID,
              let group = groups.first(where: { $0.itemIDs.contains(id) })
        else { return }
        if filterMode == .group(group.id) {
            filterMode = .all
        }
        groups.removeAll { $0.itemIDs.contains(id) }
        updateFilteredItems()
    }

    /// Rejects all members of the selected photo's group that are visible in the
    /// current pass and not already picked. Picks are left untouched.
    func rejectRestOfGroup() {
        guard let id = selectedItemID,
              let group = groups.first(where: { $0.itemIDs.contains(id) }),
              let currentPass
        else { return }
        let passPhotoIDs = currentPassPhotoIDs
        let itemsToReject = items.filter {
            group.itemIDs.contains($0.id)
                && passPhotoIDs.contains($0.id)
                && !currentPass.picks.contains($0.id)
        }
        for item in itemsToReject {
            setMark(.reject, for: item)
        }
    }

    /// Creates a group from the current selection range. Requires at least two items.
    /// Items already in other groups are moved into the new group.
    func createGroupFromSelection() {
        let items = selectedRangeItems
        guard items.count >= 2 else { return }
        let newIDs = Set(items.map(\.id))
        for index in groups.indices {
            groups[index].itemIDs.subtract(newIDs)
        }
        groups.removeAll { $0.itemIDs.isEmpty }
        groups.append(PhotoGroup(id: UUID(), colorIndex: nextGroupColorIndex(), itemIDs: newIDs))
    }

    /// Picks the color index used least often among existing groups.
    private func nextGroupColorIndex() -> Int {
        let colorCount = FolderLibrary.groupColors.count
        var usageCounts = Array(repeating: 0, count: colorCount)
        for group in groups {
            usageCounts[group.colorIndex % colorCount] += 1
        }
        return usageCounts.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
    }

    /// Resets the library to its initial empty state.
    func close() {
        folderURL = nil
        folderError = nil
        items = []
        filteredItems = []
        passes = []
        currentPassIndex = 0
        selectedItemID = nil
        rangeAnchorID = nil
        viewMode = .grid
        filterMode = .all
        lastMarkEvent = nil
        groups = []
    }

    func stats(for index: Int) -> PassStats {
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

    /// Scans the folder and resets library state. Call LibraryPersistence.restore(into:)
    /// immediately after to set up passes.
    func openFolder(url: URL) {
        folderURL = url
        folderError = nil
        viewMode = .grid
        passes = []
        currentPassIndex = 0
        do {
            items = try scanFolder(url: url)
        } catch {
            items = []
            folderError = error
            updateFilteredItems()
        }
    }

    /// Sets up a single empty pass and clears groups. Called by LibraryPersistence
    /// when no saved state exists.
    func initializeFreshPasses() {
        passes = [Pass()]
        currentPassIndex = 0
        groups = []
        updateFilteredItems()
        selectedItemID = filteredItems.first?.id
    }

    /// Applies passes restored from saved state. Called by LibraryPersistence after openFolder.
    func applyRestoredPasses(_ restoredPasses: [Pass], currentPassIndex: Int) {
        passes = restoredPasses
        self.currentPassIndex = currentPassIndex
        updateFilteredItems()
        selectedItemID = filteredItems.first?.id
    }

    /// Applies groups restored from saved state. Called by LibraryPersistence after openFolder.
    func applyRestoredGroups(_ restoredGroups: [PhotoGroup]) {
        groups = restoredGroups
    }

    /// Recomputes filteredItems from the current pass and filter mode. The pass
    /// visibility rule (a photo is visible only if unmarked in all earlier passes)
    /// is applied first; the filter mode then selects a subset of those photos.
    /// Group filters intersect the group's members with the pass-visible set, so
    /// pass visibility always takes precedence over group membership.
    private func updateFilteredItems() {
        guard let currentPass else { filteredItems = []; return }
        let passIDs = currentPassPhotoIDs
        let visibleIDs = switch filterMode {
        case .all: passIDs
        case .picked: currentPass.picks
        case .rejected: currentPass.rejects
        case .unmarked: passIDs.subtracting(currentPass.picks).subtracting(currentPass.rejects)
        case let .group(groupID):
            if let group = groups.first(where: { $0.id == groupID }) {
                passIDs.intersection(group.itemIDs)
            } else {
                passIDs
            }
        }
        filteredItems = items.filter { visibleIDs.contains($0.id) }
    }

    private func scanFolder(url: URL) throws -> [PhotoItem] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: .skipsHiddenFiles
        )
        let (rawByStem, jpegByStem) = pairFilesByType(urls: urls)
        return buildSortedItems(rawByStem: rawByStem, jpegByStem: jpegByStem)
    }

    /// Groups URLs into RAW and JPEG dictionaries keyed by filename stem.
    private func pairFilesByType(urls: [URL]) -> (rawByStem: [String: URL], jpegByStem: [String: URL]) {
        let rawExtensions: Set = ["cr2", "cr3", "nef", "arw", "dng", "raf", "orf", "rw2", "rw1", "3fr"]
        let jpegExtensions: Set = ["jpg", "jpeg"]

        var rawByStem: [String: URL] = [:]
        var jpegByStem: [String: URL] = [:]

        for fileURL in urls {
            let ext = fileURL.pathExtension.lowercased()
            let stem = fileURL.deletingPathExtension().lastPathComponent
            if rawExtensions.contains(ext) {
                rawByStem[stem] = fileURL
            } else if jpegExtensions.contains(ext) {
                jpegByStem[stem] = fileURL
            }
        }

        return (rawByStem, jpegByStem)
    }

    /// Builds PhotoItems from paired file dictionaries, sorted by creation date.
    private func buildSortedItems(rawByStem: [String: URL], jpegByStem: [String: URL]) -> [PhotoItem] {
        let allStems = Set(rawByStem.keys).union(jpegByStem.keys)
        return allStems
            .map { stem -> PhotoItem in
                // stem is in allStems (the union), so it must be in rawByStem if not jpegByStem.
                // swiftlint:disable:next force_unwrapping
                let sourceURL = jpegByStem[stem] ?? rawByStem[stem]!
                return PhotoItem(
                    id: UUID(),
                    stem: stem,
                    rawURL: rawByStem[stem],
                    jpegURL: jpegByStem[stem],
                    capturedAt: creationDate(of: sourceURL)
                )
            }
            .sorted { $0.capturedAt < $1.capturedAt }
    }

    private func creationDate(of url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date(timeIntervalSince1970: 0)
    }
}
