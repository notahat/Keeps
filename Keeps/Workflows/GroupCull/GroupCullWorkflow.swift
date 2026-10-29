import Foundation
import Observation

/// Holds the grouping state for one set of photos: the group boundaries, the
/// collapsed group temporarily expanded for editing, and the selection. The
/// grid shows cells, not photos, so this translates between cell indices
/// (what the surface speaks) and photo indices (what boundaries are made of).
/// Which groups are collapsed is never stored; GroupLayout derives it. Does
/// not scan the folder, load images, or persist state.
@Observable
class GroupCullWorkflow {
    let items: [PhotoItem]
    private(set) var boundaries: Set<Int> = []
    private(set) var expandedRange: Range<Int>?
    private(set) var selectedPhotoIndex: Int?

    init(items: [PhotoItem]) {
        self.items = items
        selectedPhotoIndex = items.isEmpty ? nil : 0
    }

    /// The current groups and grid cells, derived from the boundaries.
    var layout: GroupLayout {
        GroupLayout(photoCount: items.count, boundaries: boundaries, expandedRange: expandedRange)
    }

    /// The photo each cell displays: its own photo, or a collapsed group's
    /// first photo.
    var displayedItems: [PhotoItem] {
        layout.cells.map { items[$0.photoRange.lowerBound] }
    }

    /// The cell showing the selected photo.
    var selectedCellIndex: Int? {
        selectedPhotoIndex.flatMap { layout.cellIndex(containing: $0) }
    }

    /// Toggles the boundary at a gap between cells, identified by the index
    /// of the cell after it.
    func toggleBoundary(atGap gapIndex: Int) {
        toggleBoundary(atPhoto: layout.photoIndex(forGap: gapIndex))
    }

    /// Toggles the boundary before the given photo. A boundary placed
    /// outside the expanded group counts as moving on, so the group
    /// collapses again; one on its edges or inside it is editing it. The
    /// folder always starts a group, so there is no boundary before photo 0.
    func toggleBoundary(atPhoto photoIndex: Int) {
        guard photoIndex >= 1, photoIndex <= items.count else { return }
        if boundaries.contains(photoIndex) {
            boundaries.remove(photoIndex)
        } else {
            boundaries.insert(photoIndex)
            if let expandedRange, !(expandedRange.lowerBound ... expandedRange.upperBound).contains(photoIndex) {
                self.expandedRange = nil
            }
        }
    }

    /// Selects a cell without expanding or collapsing anything, for keyboard
    /// navigation.
    func selectCell(at cellIndex: Int) {
        let cells = layout.cells
        guard cells.indices.contains(cellIndex) else { return }
        selectedPhotoIndex = cells[cellIndex].photoRange.lowerBound
    }

    /// Handles a click on a cell. Clicking a collapsed group expands it;
    /// clicking a photo selects it and collapses any expanded group it is
    /// not part of.
    func tapCell(at cellIndex: Int) {
        let cells = layout.cells
        guard cells.indices.contains(cellIndex) else { return }
        switch cells[cellIndex] {
        case let .collapsedGroup(range):
            expandedRange = range
            selectedPhotoIndex = range.lowerBound
        case let .photo(photoIndex):
            if let expandedRange, !expandedRange.contains(photoIndex) {
                self.expandedRange = nil
            }
            selectedPhotoIndex = photoIndex
        }
    }
}
