import Foundation
import Observation

/// The model of one folder's work: how its photos are split into groups,
/// and what has been picked from them.
///
/// The user splits the folder by placing boundaries between photos. Each
/// group runs from one boundary to the next, and the folder's start always
/// begins one. The photos after the last boundary aren't in a group yet.
/// The user collapses groups as they move on, and a collapsed group can't
/// change. On the pick screen the user opens a group, picks its keepers,
/// and marks it done. Closing the open group means leaving the pick screen.
///
/// Grouping holds the boundaries, the collapse point, the selection, the
/// sort screen's scroll position, the open and last opened groups, the
/// keepers, and the done groups. The sort screen shows cells, not photos,
/// so Grouping translates between cell indices, which the screen uses, and
/// photo indices, which boundaries are made of; GroupLayout derives the
/// cells. Grouping converts itself to and from SavedGrouping for saving,
/// but doesn't scan the folder, load images, or write files.
@Observable
class Grouping {
    /// The folder's photos, in folder order. Every photo index refers to
    /// this list.
    let items: [PhotoItem]

    /// The boundaries, each the index of the photo just after it (see
    /// GroupLayout).
    private(set) var boundaries: Set<Int> = [] {
        didSet { updateLayout() }
    }

    /// The selected photo. A selected collapsed group is held as its first
    /// photo.
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

    /// The group most recently opened, kept after it closes so the done
    /// screen can show it selected when the user comes back. Not saved:
    /// nil when no group has been opened since the folder was opened.
    private(set) var lastOpenedGroup: Range<Int>?

    /// The photos picked to keep.
    private(set) var keepers: Set<Int> = []

    /// The groups marked done, by the index of each one's first photo. Done
    /// groups are always collapsed, so their first photos never move.
    private var doneGroupStarts: Set<Int> = [] {
        didSet { updateLayout() }
    }

    /// The current groups and grid cells, derived from the boundaries, the
    /// collapse point, and the done groups. Kept rather than computed on
    /// demand because the grid reads it several times per render, and each
    /// derivation walks the whole folder.
    private(set) var layout: GroupLayout

    /// Converts photos to and from the stems they're saved by.
    @ObservationIgnored private let stems: PhotoStems

    /// Starts a grouping of the given photos with no boundaries, and nothing
    /// collapsed, selected, open, kept, or done.
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

    // MARK: - Sort screen

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
        guard layout.isGapEditable(gapIndex) else { return }
        toggleBoundary(atPhoto: layout.photoIndex(forGap: gapIndex))
    }

    /// Toggles the boundary before the given photo. The folder always
    /// starts a group, so there is no boundary before photo 0.
    func toggleBoundary(atPhoto photoIndex: Int) {
        guard photoIndex >= 1, photoIndex <= items.count else { return }
        boundaries.toggle(photoIndex)
    }

    /// Selects a cell. A collapsed group is selected via its first photo.
    func selectCell(at cellIndex: Int) {
        guard layout.cells.indices.contains(cellIndex) else { return }
        selectedPhotoIndex = layout.cells[cellIndex].photoRange.lowerBound
    }

    /// Deselects everything.
    func clearSelection() {
        selectedPhotoIndex = nil
    }

    /// Collapses every group, which is every photo up to the last boundary.
    func collapseGroups() {
        collapsedUpTo = boundaries.max() ?? 0
    }

    /// Opens the group that a sort screen cell belongs to (see open(_:)).
    /// Photos after the working point aren't in a group, so their cells open
    /// nothing.
    func open(groupAtCell cellIndex: Int) {
        guard layout.cells.indices.contains(cellIndex) else { return }
        let photoIndex = layout.cells[cellIndex].photoRange.lowerBound
        guard let group = layout.groups.first(where: { $0.contains(photoIndex) }) else { return }
        open(group)
    }

    // MARK: - Pick screen

    /// Opens a group on the pick screen, whether or not it's done.
    /// Every group up to and including it is collapsed first, so its photos
    /// can't change while it's open; later groups that are already collapsed
    /// stay collapsed. The group is also selected, so the sort screen shows
    /// it when the user comes back. Anything that isn't a group opens
    /// nothing.
    func open(_ group: Range<Int>) {
        guard layout.groups.contains(group) else { return }
        collapsedUpTo = max(collapsedUpTo, group.upperBound)
        openGroup = group
        lastOpenedGroup = group
        selectedPhotoIndex = group.lowerBound
    }

    /// Marks a photo as a keeper, or unmarks it if it already is one.
    func toggleKeeper(atPhoto photoIndex: Int) {
        guard items.indices.contains(photoIndex) else { return }
        keepers.toggle(photoIndex)
    }

    /// Marks the open group done, leaving it open.
    func markOpenGroupDone() {
        guard let openGroup else { return }
        doneGroupStarts.insert(openGroup.lowerBound)
    }

    /// Marks the open group not done, leaving it open. Once closed, it
    /// shows on the sort screen's grid again, for the user to work on.
    func markOpenGroupNotDone() {
        guard let openGroup else { return }
        doneGroupStarts.remove(openGroup.lowerBound)
    }

    /// Closes the open group, so the pick screen goes away, leaving whether
    /// the group is done unchanged. When it's done, the user has finished
    /// with it, so the selection moves on to the next group that isn't
    /// done, or to the working point when there is none, ready for the user
    /// to open with Return.
    func closeOpenGroup() {
        guard let closed = openGroup else { return }
        openGroup = nil
        guard isDone(closed) else { return }
        let next = layout.groups.first { $0.lowerBound >= closed.upperBound && !isDone($0) }
        selectedPhotoIndex = next?.lowerBound ?? workingPointPhotoIndex
    }

    // MARK: - Done groups and keepers

    /// Whether a group has been marked done.
    func isDone(_ group: Range<Int>) -> Bool {
        doneGroupStarts.contains(group.lowerBound)
    }

    /// How many of a group's photos are keepers.
    func keptCount(in group: Range<Int>) -> Int {
        group.count { keepers.contains($0) }
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

    /// Whether every photo is in a done group, so the folder is finished.
    var isAllDone: Bool {
        photosToGo.isEmpty
    }

    // MARK: - Saving

    /// A snapshot of everything worth saving, with photos named by their
    /// stems. KeepsFile calls this inside an observation block, and reading
    /// each saved property here is what subscribes it to that property's
    /// changes: anything left out of the snapshot would change without
    /// triggering a save.
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

private extension Set {
    /// Removes a member if it's there, otherwise inserts it.
    mutating func toggle(_ member: Element) {
        if contains(member) {
            remove(member)
        } else {
            insert(member)
        }
    }
}
