import Foundation
import Observation

/// Holds the culling state for one set of photos: flat pick/reject marks,
/// selection, view mode, and filtering, plus the cross-cutting actions that
/// span them. Does not scan or own the folder (that's FolderSession's job),
/// load image data (ImagePipeline's job), or persist state
/// (WorkflowPersistence's job).
@Observable
class FolderLibrary {
    enum ViewMode { case grid, single }
    enum FilterMode: Equatable, Hashable { case all, picked, rejected, unmarked }

    /// Set when persistence fails to write keeps.json. The UI observes this
    /// to alert the user that their marks may not have been saved.
    private(set) var saveError: Error?
    private(set) var selectedItemID: UUID?
    private(set) var rangeAnchorID: UUID?
    var viewMode: ViewMode = .grid
    var filterMode: FilterMode = .all
    let items: [PhotoItem]
    private(set) var filteredItems: [PhotoItem] = []
    private var markStore = MarkStore()

    init(items: [PhotoItem]) {
        self.items = items
        updateFilteredItems()
        selectedItemID = filteredItems.first?.id
    }

    /// Returns the mark for a photo, or nil if unmarked.
    func mark(for id: UUID) -> MarkStore.Mark? {
        markStore.mark(for: id)
    }

    /// Groups all photos by their mark for sorting into folders.
    func sortPlan() -> [MarkStore.Mark?: [PhotoItem]] {
        markStore.sortPlan(items: items)
    }

    /// Set each time applyMarkAndAdvance is called, so observers can react to
    /// mark actions regardless of which code path triggered them.
    private(set) var lastMarkEvent: MarkEvent?

    /// Uniquely identifies a single mark application, so observers can detect
    /// repeated applications of the same mark value.
    struct MarkEvent: Equatable {
        let mark: MarkStore.Mark?
        private let token = UUID()

        static func == (lhs: MarkEvent, rhs: MarkEvent) -> Bool {
            lhs.token == rhs.token
        }
    }

    /// The index of the selected item within the current filtered list, or nil if the
    /// selected item isn't present in the current filter. Setting this updates the
    /// selected item identity, so the selection follows the item across filter changes.
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

    /// Sets, changes, or clears the mark for a photo. Recomputes the filtered
    /// list when a non-`.all` filter is active so the view reflects the new mark.
    func setMark(_ mark: MarkStore.Mark?, for item: PhotoItem) {
        markStore.setMark(mark, for: item.id)
        if filterMode != .all {
            updateFilteredItems()
        }
    }

    /// Marks the selected item(s) and advances. When a multi-item range is selected,
    /// marks all items in the range without advancing or collapsing the range, so
    /// the user can easily undo an accidental bulk mark. When a single item is
    /// selected, marks it and moves to the next item.
    func applyMarkAndAdvance(_ mark: MarkStore.Mark?) {
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

    func applyFilter(_ mode: FilterMode) {
        filterMode = mode
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

    /// Reports a failure to persist library state to disk. Called by the
    /// persistence observation when keeps.json could not be written.
    func recordSaveError(_ error: Error) {
        saveError = error
    }

    /// Clears any reported save error. Called by the UI after the user has
    /// acknowledged the failure.
    func clearSaveError() {
        saveError = nil
    }

    /// A stem-keyed snapshot of the current marks, for persistence. Reading
    /// this inside an observation block also subscribes it to mark changes.
    func snapshotState() -> SimpleCullState {
        let stemByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.stem) })
        return SimpleCullState(
            picks: markStore.marks.compactMap { id, mark in mark == .pick ? stemByID[id] : nil }.sorted(),
            rejects: markStore.marks.compactMap { id, mark in mark == .reject ? stemByID[id] : nil }.sorted()
        )
    }

    /// Replaces the marks with restored state, dropping stems that no longer
    /// exist in the folder, and resets the selection.
    func applyRestored(state: SimpleCullState) {
        let idByStem = Dictionary(uniqueKeysWithValues: items.map { ($0.stem, $0.id) })
        var marks: [UUID: MarkStore.Mark] = [:]
        for stem in state.picks {
            if let id = idByStem[stem] {
                marks[id] = .pick
            }
        }
        for stem in state.rejects {
            if let id = idByStem[stem] {
                marks[id] = .reject
            }
        }
        markStore.applyRestored(marks: marks)
        updateFilteredItems()
        selectedItemID = filteredItems.first?.id
    }

    /// Recomputes filteredItems from the current filter mode.
    private func updateFilteredItems() {
        filteredItems = switch filterMode {
        case .all: items
        case .picked: items.filter { markStore.mark(for: $0.id) == .pick }
        case .rejected: items.filter { markStore.mark(for: $0.id) == .reject }
        case .unmarked: items.filter { markStore.mark(for: $0.id) == nil }
        }
    }
}
