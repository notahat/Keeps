import Foundation
import Observation

/// Holds the grouping state for one set of photos: the group boundaries, how
/// far groups have been collapsed, the selection, the last reported scroll
/// position, and the narrowing state (the open group, the keepers, and which
/// groups are done). The sort screen shows cells, not photos, so this
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

    /// The group shown on the pick screen, or nil while the sort screen is
    /// showing. Always collapsed, so its photos can't change while it's open.
    private(set) var openGroup: Range<Int>?

    /// The photos picked to keep.
    private(set) var keepers: Set<Int> = []

    /// The groups marked done, by the index of each one's first photo. Done
    /// groups are always collapsed, so their first photos never move.
    private var doneGroupStarts: Set<Int> = [] {
        didSet { updateLayout() }
    }

    /// The current groups and grid cells, derived from the boundaries, the
    /// collapse point, and the done groups. Kept rather than computed on demand because the
    /// grid reads it several times per render, and each derivation walks the
    /// whole folder.
    private(set) var layout: GroupLayout

    /// Converts photos to and from the stems they're saved by.
    @ObservationIgnored private let stems: PhotoStems

    init(items: [PhotoItem]) {
        self.items = items
        stems = PhotoStems(items: items)
        layout = GroupLayout(photoCount: items.count, boundaries: [])
    }

    /// Rederives the layout after the boundaries, collapse point, or done
    /// groups change.
    private func updateLayout() {
        layout = GroupLayout(
            photoCount: items.count,
            boundaries: boundaries,
            collapsedUpTo: collapsedUpTo,
            doneGroupStarts: doneGroupStarts
        )
    }

    /// The photo each cell shows: its own photo, or a collapsed group's
    /// first photo. The sort screen identifies cells, and saves its scroll
    /// position, by this photo.
    var cellItems: [PhotoItem] {
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

    /// Opens the closed group a sort-screen cell belongs to, collapsing every
    /// group up to and including it. Photos after the working point
    /// aren't in a group, so their cells open nothing.
    func open(groupAtCell cellIndex: Int) {
        let layout = layout
        guard layout.cells.indices.contains(cellIndex) else { return }
        let photoIndex = layout.cells[cellIndex].photoRange.lowerBound
        guard let group = layout.groups.first(where: { $0.contains(photoIndex) }) else { return }
        open(group)
    }

    /// Marks the open group done, leaving it open.
    func markOpenGroupDone() {
        guard let openGroup else { return }
        doneGroupStarts.insert(openGroup.lowerBound)
    }

    /// Marks the open group not done, leaving it open, so it's worked on
    /// again and comes back to the sort screen's grid.
    func markOpenGroupNotDone() {
        guard let openGroup else { return }
        doneGroupStarts.remove(openGroup.lowerBound)
    }

    /// Closes the open group, leaving whether it is done unchanged. A done
    /// group is finished with, so the selection moves on to the next group
    /// that isn't done, or the working point when there is none, ready to
    /// open with Return.
    func closeOpenGroup() {
        guard let closed = openGroup else { return }
        openGroup = nil
        guard isDone(closed) else { return }
        let next = layout.groups.first { $0.lowerBound >= closed.upperBound && !isDone($0) }
        selectedPhotoIndex = next?.lowerBound ?? workingPointPhotoIndex
    }

    /// Whether a closed group has been marked done.
    func isDone(_ group: Range<Int>) -> Bool {
        doneGroupStarts.contains(group.lowerBound)
    }

    /// How many groups have been marked done.
    var doneGroupCount: Int {
        doneGroupStarts.count
    }

    /// The done groups, latest first.
    var doneGroups: [Range<Int>] {
        layout.groups.filter(isDone).reversed()
    }

    /// The keepers of the done groups, in pile order: the latest group's
    /// first, and each group's in folder order.
    var keepersOfDoneGroups: [Int] {
        doneGroups.flatMap { group in group.filter(keepers.contains) }
    }

    /// The photos of the done groups that weren't kept, in the same order
    /// as keepersOfDoneGroups.
    var setAsideFromDoneGroups: [Int] {
        doneGroups.flatMap { group in group.filter { !keepers.contains($0) } }
    }

    /// The photos not yet in a done group, in folder order, so the next to
    /// work on comes first.
    var photosToGo: [Int] {
        let done = Set(doneGroups.joined())
        return items.indices.filter { !done.contains($0) }
    }

    /// Marks a photo as a keeper, or unmarks it if it already is one.
    func toggleKeeper(atPhoto photoIndex: Int) {
        guard items.indices.contains(photoIndex) else { return }
        if keepers.contains(photoIndex) {
            keepers.remove(photoIndex)
        } else {
            keepers.insert(photoIndex)
        }
    }

    /// Opens a closed group, done or not: collapses every group up to and
    /// including it, without reopening any collapsed later, then opens and
    /// selects it. Selecting it means the sort screen shows it on return.
    /// Anything that isn't a closed group opens nothing.
    func open(_ group: Range<Int>) {
        guard layout.groups.contains(group) else { return }
        collapsedUpTo = max(collapsedUpTo, group.upperBound)
        openGroup = group
        selectedPhotoIndex = group.lowerBound
    }

    /// A stem-keyed snapshot of everything worth saving. Reading this inside
    /// an observation block also subscribes to changes in all of it.
    func snapshotState() -> SavedGrouping {
        SavedGrouping(
            boundaries: boundaries.sorted().map(stems.position(beforePhoto:)),
            collapsedUpTo: collapsedUpTo > 0 ? stems.position(beforePhoto: collapsedUpTo) : nil,
            selectedStem: selectedPhotoIndex.map { items[$0].stem },
            scrollAnchor: scrollAnchor.flatMap { anchor in
                stems.stem(ofItemID: anchor.itemID).map {
                    SavedGrouping.ScrollAnchor(stem: $0, offsetFromRowTop: anchor.offsetFromRowTop)
                }
            },
            keeperStems: stems.stems(ofPhotos: keepers),
            doneGroupStartStems: stems.stems(ofPhotos: doneGroupStarts)
        )
    }

    /// Replaces the state with restored state, dropping anything that refers
    /// to a photo no longer in the folder.
    func applyRestored(state: SavedGrouping) {
        boundaries = Set(state.boundaries.compactMap(stems.photoIndex(at:)))
        collapsedUpTo = state.collapsedUpTo.flatMap(stems.photoIndex(at:)) ?? 0
        selectedPhotoIndex = state.selectedStem.flatMap(stems.photoIndex(ofStem:))
        scrollAnchor = state.scrollAnchor.flatMap { anchor in
            stems.photoIndex(ofStem: anchor.stem).map {
                GridScrollAnchor(itemID: items[$0].id, offsetFromRowTop: anchor.offsetFromRowTop)
            }
        }
        keepers = stems.photoIndices(ofStems: state.keeperStems)
        doneGroupStarts = stems.photoIndices(ofStems: state.doneGroupStartStems)
    }
}
