import Foundation
import Observation

/// Holds the grouping state for one set of photos: the group boundaries, how
/// far groups have been collapsed, and the selection. The grid shows cells,
/// not photos, so this translates between cell indices (what the surface
/// speaks) and photo indices (what boundaries are made of). GroupLayout
/// derives the cells from this state. Does not scan the folder, load images,
/// or persist state.
@Observable
class GroupCullWorkflow {
    let items: [PhotoItem]
    private(set) var boundaries: Set<Int> = []
    private(set) var selectedPhotoIndex: Int?

    /// The photo index up to which groups are collapsed; 0 for none. Set
    /// only by collapsing, and never undone, so the gaps beside collapsed
    /// groups are locked (see GroupLayout.isGapEditable).
    private(set) var collapsedUpTo = 0

    init(items: [PhotoItem]) {
        self.items = items
    }

    /// The current groups and grid cells, derived from the boundaries and
    /// the collapse point.
    var layout: GroupLayout {
        GroupLayout(photoCount: items.count, boundaries: boundaries, collapsedUpTo: collapsedUpTo)
    }

    /// The photo each cell displays: its own photo, or a collapsed group's
    /// first photo.
    var displayedItems: [PhotoItem] {
        layout.cells.map { items[$0.photoRange.lowerBound] }
    }

    /// Where grouping has reached: the first photo after the last boundary,
    /// or nil before any boundary or once every photo is grouped.
    var workingPointPhotoIndex: Int? {
        guard let lastBoundary = boundaries.max(), lastBoundary < items.count else { return nil }
        return lastBoundary
    }

    /// The cell showing the selected photo.
    var selectedCellIndex: Int? {
        selectedPhotoIndex.flatMap { layout.cellIndex(containing: $0) }
    }

    /// Toggles the boundary at a gap between cells, identified by the index
    /// of the cell after it. Locked gaps (see GroupLayout.isGapEditable) are
    /// left alone.
    func toggleBoundary(atGap gapIndex: Int) {
        let layout = layout
        guard layout.isGapEditable(gapIndex) else { return }
        toggleBoundary(atPhoto: layout.photoIndex(forGap: gapIndex))
    }

    /// Toggles the boundary before the given photo. The folder always
    /// starts a group, so there is no boundary before photo 0.
    func toggleBoundary(atPhoto photoIndex: Int) {
        guard photoIndex >= 1, photoIndex <= items.count else { return }
        if boundaries.contains(photoIndex) {
            boundaries.remove(photoIndex)
        } else {
            boundaries.insert(photoIndex)
        }
    }

    /// Selects a cell. A collapsed group is selected via its first photo.
    func selectCell(at cellIndex: Int) {
        let cells = layout.cells
        guard cells.indices.contains(cellIndex) else { return }
        selectedPhotoIndex = cells[cellIndex].photoRange.lowerBound
    }

    /// Collapses every group closed so far.
    func collapseClosedGroups() {
        collapsedUpTo = boundaries.max() ?? 0
    }

    /// Deselects everything.
    func clearSelection() {
        selectedPhotoIndex = nil
    }
}
