import Foundation
import Observation

/// Holds the grouping state for one set of photos: the group boundaries, how
/// far groups have been collapsed, the selection, and the last reported
/// scroll position. The sort screen shows cells, not photos, so this
/// translates between cell indices (what the screen speaks) and photo indices
/// (what boundaries are made of). GroupLayout derives the cells from this state.
/// Translates to and from SavedGrouping for saving, but does not scan the
/// folder, load images, or write files.
@Observable
class Grouping {
    let items: [PhotoItem]
    private(set) var boundaries: Set<Int> = [] {
        didSet { updateLayout() }
    }

    private(set) var selectedPhotoIndex: Int?

    /// The grid's scroll position, bound to the grid, which writes it only
    /// when it changes.
    var scrollAnchor: GridScrollAnchor?

    /// The photo index up to which groups are collapsed; 0 for none. Set
    /// only by collapsing, and never undone, so the gaps beside collapsed
    /// groups are locked (see GroupLayout.isGapEditable).
    private(set) var collapsedUpTo = 0 {
        didSet { updateLayout() }
    }

    /// The current groups and grid cells, derived from the boundaries and
    /// the collapse point. Kept rather than computed on demand because the
    /// grid reads it several times per render, and each derivation walks the
    /// whole folder.
    private(set) var layout: GroupLayout

    init(items: [PhotoItem]) {
        self.items = items
        layout = GroupLayout(photoCount: items.count, boundaries: [])
    }

    /// Rederives the layout after the boundaries or collapse point change.
    private func updateLayout() {
        layout = GroupLayout(photoCount: items.count, boundaries: boundaries, collapsedUpTo: collapsedUpTo)
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

    /// A stem-keyed snapshot of everything worth saving. Reading this inside
    /// an observation block also subscribes to changes in all of it.
    func snapshotState() -> SavedGrouping {
        let stemByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.stem) })
        return SavedGrouping(
            boundaries: boundaries.sorted().map(position(forPhoto:)),
            collapsedUpTo: collapsedUpTo > 0 ? position(forPhoto: collapsedUpTo) : nil,
            selectedStem: selectedPhotoIndex.map { items[$0].stem },
            scrollAnchor: scrollAnchor.flatMap { anchor in
                stemByID[anchor.itemID].map {
                    SavedGrouping.ScrollAnchor(stem: $0, offsetFromRowTop: anchor.offsetFromRowTop)
                }
            }
        )
    }

    /// Replaces the state with restored state, dropping anything that refers
    /// to a photo no longer in the folder.
    func applyRestored(state: SavedGrouping) {
        let indexByStem = Dictionary(uniqueKeysWithValues: items.enumerated().map { ($1.stem, $0) })
        boundaries = Set(state.boundaries.compactMap { photoIndex(for: $0, indexByStem: indexByStem) })
        collapsedUpTo = state.collapsedUpTo.flatMap { photoIndex(for: $0, indexByStem: indexByStem) } ?? 0
        selectedPhotoIndex = state.selectedStem.flatMap { indexByStem[$0] }
        scrollAnchor = state.scrollAnchor.flatMap { anchor in
            indexByStem[anchor.stem].map {
                GridScrollAnchor(itemID: items[$0].id, offsetFromRowTop: anchor.offsetFromRowTop)
            }
        }
    }

    /// The saved form of the point just before a photo, or after the last
    /// one when the index is the photo count.
    private func position(forPhoto photoIndex: Int) -> SavedGrouping.Position {
        photoIndex < items.count ? .beforePhoto(items[photoIndex].stem) : .end
    }

    /// The photo index a saved position refers to, or nil if its photo is no
    /// longer in the folder.
    private func photoIndex(for position: SavedGrouping.Position, indexByStem: [String: Int]) -> Int? {
        switch position {
        case let .beforePhoto(stem): indexByStem[stem]
        case .end: items.count
        }
    }
}
