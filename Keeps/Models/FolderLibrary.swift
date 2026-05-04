import Foundation
import Observation
import SwiftUI

/// Owns the photo items for a single open folder and orchestrates the
/// sub-stores that hold pass/mark and group state. Handles selection, view
/// mode, filtering, and the cross-cutting actions that span sub-stores. Does
/// not load image data (that's ImagePipeline's job) or persist state (that's
/// LibraryPersistence's job).
@Observable
class FolderLibrary {
    enum ViewMode { case grid, single }
    enum FilterMode: Equatable, Hashable { case all, picked, rejected, unmarked, group(UUID) }

    private(set) var folderURL: URL?
    private(set) var folderError: Error?
    /// Set when LibraryPersistence fails to write keeps.json. The UI observes
    /// this to alert the user that their marks may not have been saved.
    private(set) var saveError: Error?
    private(set) var selectedItemID: UUID?
    private(set) var rangeAnchorID: UUID?
    var viewMode: ViewMode = .grid
    var filterMode: FilterMode = .all
    private(set) var items: [PhotoItem] = []
    private(set) var filteredItems: [PhotoItem] = []
    private var passStore = PassStore()
    private var groupStore = GroupStore()

    var groups: [GroupStore.PhotoGroup] {
        groupStore.groups
    }

    var passes: [PassStore.Pass] {
        passStore.passes
    }

    var currentPassIndex: Int {
        passStore.currentPassIndex
    }

    var canStartNextPass: Bool {
        passStore.canStartNextPass
    }

    /// Returns the mark for a photo in the currently viewed pass, or nil if unmarked.
    func mark(for id: UUID) -> PassStore.Mark? {
        passStore.mark(for: id)
    }

    /// Returns the cumulative mark for a photo across all passes. The last
    /// pass to mark the photo wins. Returns nil if never marked.
    func cumulativeMark(for id: UUID) -> PassStore.Mark? {
        passStore.cumulativeMark(for: id)
    }

    /// Groups all photos by their cumulative mark for sorting into folders.
    func sortPlan() -> [PassStore.Mark?: [PhotoItem]] {
        passStore.sortPlan(items: items)
    }

    /// Pick/reject/total counts for the pass at the given index.
    func stats(for index: Int) -> PassStore.PassStats {
        passStore.stats(for: index, items: items)
    }

    /// Set each time applyMarkAndAdvance is called, so observers can react to
    /// mark actions regardless of which code path triggered them.
    private(set) var lastMarkEvent: MarkEvent?

    /// Uniquely identifies a single mark application, so observers can detect
    /// repeated applications of the same mark value.
    struct MarkEvent: Equatable {
        let mark: PassStore.Mark?
        private let token = UUID()

        static func == (lhs: MarkEvent, rhs: MarkEvent) -> Bool {
            lhs.token == rhs.token
        }
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

    /// Sets, changes, or clears the mark for a photo in the current pass.
    /// Recomputes the filtered list when a non-`.all` filter is active so the
    /// view reflects the new mark.
    func setMark(_ mark: PassStore.Mark?, for item: PhotoItem) {
        passStore.setMark(mark, for: item.id)
        if filterMode != .all { updateFilteredItems() }
    }

    /// Marks the selected item(s) and advances. When a multi-item range is selected,
    /// marks all items in the range without advancing or collapsing the range, so
    /// the user can easily undo an accidental bulk mark. When a single item is
    /// selected, marks it and moves to the next item.
    func applyMarkAndAdvance(_ mark: PassStore.Mark?) {
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

    /// Creates a new pass and resets filter and selection. Photos not marked in the
    /// previous pass appear in the new one.
    func startNextPass() {
        passStore.startNextPass()
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

    /// Switches to the pass at the given index and resets filter and selection.
    func selectPass(_ index: Int) {
        passStore.selectPass(index)
        filterMode = .all
        updateFilteredItems()
        selectedIndex = filteredItems.isEmpty ? nil : 0
        rangeAnchorID = nil
    }

    /// The items spanned by the current selection range, or an empty array if no
    /// multi-item range is active.
    var selectedRangeItems: [PhotoItem] {
        guard let range = selectionRange else { return [] }
        return Array(filteredItems[range])
    }

    /// The color assigned to the group that contains this photo, or nil if ungrouped.
    func groupColor(for id: UUID) -> Color? {
        groupStore.color(forItem: id)
    }

    /// True when the currently selected photo belongs to any group.
    var selectedItemIsGrouped: Bool {
        guard let id = selectedItemID else { return false }
        return groupStore.group(containing: id) != nil
    }

    /// True when the grid is filtered to a single group.
    var isGroupFocused: Bool {
        if case .group = filterMode { return true }
        return false
    }

    /// The color of the currently focused group, or nil if not in group focus mode.
    var focusedGroupColor: Color? {
        guard case let .group(groupID) = filterMode else { return nil }
        return groupStore.color(forGroup: groupID)
    }

    /// Focuses the grid on the group containing the selected photo, keeping the
    /// current selection in place.
    func focusSelectedItemGroup() {
        guard let id = selectedItemID,
              let group = groupStore.group(containing: id)
        else { return }
        filterMode = .group(group.id)
        updateFilteredItems()
        rangeAnchorID = selectedItemID
    }

    /// Removes the group that contains the currently selected photo. Resets group
    /// focus if the focused group is the one being deleted.
    func ungroupSelectedItem() {
        guard let id = selectedItemID,
              let group = groupStore.group(containing: id)
        else { return }
        if filterMode == .group(group.id) {
            filterMode = .all
        }
        groupStore.removeGroup(containing: id)
        updateFilteredItems()
    }

    /// Rejects all members of the selected photo's group that are visible in the
    /// current pass and not already picked. Picks are left untouched.
    func rejectRestOfGroup() {
        guard let id = selectedItemID,
              let group = groupStore.group(containing: id),
              let currentPass = passStore.currentPass
        else { return }
        let passPhotoIDs = passStore.currentPassPhotoIDs(items: items)
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
        groupStore.addGroup(itemIDs: Set(items.map(\.id)))
    }

    /// Resets the library to its initial empty state.
    func close() {
        folderURL = nil
        folderError = nil
        saveError = nil
        items = []
        filteredItems = []
        passStore.reset()
        groupStore.reset()
        selectedItemID = nil
        rangeAnchorID = nil
        viewMode = .grid
        filterMode = .all
        lastMarkEvent = nil
    }

    /// Reports a failure to persist library state to disk. Called by
    /// LibraryPersistence when keeps.json could not be written.
    func recordSaveError(_ error: Error) {
        saveError = error
    }

    /// Clears any reported save error. Called by the UI after the user has
    /// acknowledged the failure.
    func clearSaveError() {
        saveError = nil
    }

    /// Scans the folder and resets library state. Call LibraryPersistence.restore(into:)
    /// immediately after to set up passes.
    func openFolder(url: URL) {
        folderURL = url
        folderError = nil
        viewMode = .grid
        passStore.reset()
        do {
            items = try FolderScanner.scan(url: url)
        } catch {
            items = []
            folderError = error
            updateFilteredItems()
        }
    }

    /// Sets up a single empty pass and clears groups. Called by LibraryPersistence
    /// when no saved state exists.
    func initializeFreshPasses() {
        passStore.initializeFresh()
        groupStore.reset()
        updateFilteredItems()
        selectedItemID = filteredItems.first?.id
    }

    /// Applies passes restored from saved state. Called by LibraryPersistence after openFolder.
    func applyRestoredPasses(_ restoredPasses: [PassStore.Pass], currentPassIndex: Int) {
        passStore.applyRestored(passes: restoredPasses, currentPassIndex: currentPassIndex)
        updateFilteredItems()
        selectedItemID = filteredItems.first?.id
    }

    /// Applies groups restored from saved state. Called by LibraryPersistence after openFolder.
    func applyRestoredGroups(_ restoredGroups: [GroupStore.PhotoGroup]) {
        groupStore.applyRestored(restoredGroups)
    }

    /// Recomputes filteredItems from the current pass and filter mode. The pass
    /// visibility rule (a photo is visible only if unmarked in all earlier passes)
    /// is applied first; the filter mode then selects a subset of those photos.
    /// Group filters intersect the group's members with the pass-visible set, so
    /// pass visibility always takes precedence over group membership.
    private func updateFilteredItems() {
        guard let currentPass = passStore.currentPass else { filteredItems = []; return }
        let passIDs = passStore.currentPassPhotoIDs(items: items)
        let visibleIDs = switch filterMode {
        case .all: passIDs
        case .picked: currentPass.picks
        case .rejected: currentPass.rejects
        case .unmarked: passIDs.subtracting(currentPass.picks).subtracting(currentPass.rejects)
        case let .group(groupID):
            if let group = groupStore.groups.first(where: { $0.id == groupID }) {
                passIDs.intersection(group.itemIDs)
            } else {
                passIDs
            }
        }
        filteredItems = items.filter { visibleIDs.contains($0.id) }
    }
}
