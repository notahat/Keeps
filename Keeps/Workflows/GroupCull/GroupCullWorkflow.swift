import Foundation
import Observation

/// Holds the grouping state for one set of photos: the group boundaries and
/// the selection. The grid shows cells, not photos, so this translates
/// between cell indices (what the surface speaks) and photo indices (what
/// boundaries are made of). Which groups are collapsed is never stored;
/// GroupLayout derives it. Does not scan the folder, load images, or persist
/// state.
@Observable
class GroupCullWorkflow {
    let items: [PhotoItem]
    private(set) var boundaries: Set<Int> = []
    private(set) var selectedPhotoIndex: Int?

    init(items: [PhotoItem]) {
        self.items = items
    }

    /// The current groups and grid cells, derived from the boundaries.
    var layout: GroupLayout {
        GroupLayout(photoCount: items.count, boundaries: boundaries)
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

    /// Deselects everything.
    func clearSelection() {
        selectedPhotoIndex = nil
    }
}
