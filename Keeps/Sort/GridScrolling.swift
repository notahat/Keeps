import SwiftUI

/// Controls where the sort screen's grid is scrolled to. Cells disappear
/// from the grid as groups collapse, and on its own the scroll view would
/// let the photos below jump up the screen. GridScrolling holds the working
/// point still instead. It also restores the saved scroll position when the
/// screen opens, scrolls to follow keyboard selection, and reports the
/// scroll position so it can be saved.
///
/// SortScreen owns one, attaches it to its scroll view with `gridScrolling`,
/// tells it the column count once the grid is measured, and tells it about
/// clicks and key presses before acting on them. GridScrolling doesn't draw
/// anything or handle input itself. GridScrollResponse decides what a
/// change calls for, and the geometry it works from is in PhotoGridMetrics.
@Observable
final class GridScrolling {
    /// What the grid is showing, as far as scrolling cares.
    nonisolated struct Cells: Equatable {
        /// The photo each cell shows, in order. The grid identifies each
        /// cell by its photo's id.
        let photoIDs: [UUID]

        /// The selected cell's photo, or nil when nothing is selected.
        let selectedPhotoID: UUID?

        /// A photo to keep at the same height on screen whenever the cells
        /// change, such as the working point. When nil, the cell the user
        /// last clicked, or the middle of the view after a key press, is
        /// held instead.
        let stablePhotoID: UUID?

        /// Empty slots asked for before the first cell. Only the remainder
        /// by the column count is shown (see blankSlotCount).
        let leadingBlankSlots: Int
    }

    /// What the scroll view watches for changes: the cells, and how many
    /// blank slots were shown before them. A change to either may need a
    /// scroll, and respondToChange works out whether it does.
    struct Trigger: Equatable {
        fileprivate let cells: Cells
        fileprivate let blankSlotCount: Int

        /// Where the cells sit, for working out how far a cell has moved.
        fileprivate var slottedCells: PhotoGridMetrics.SlottedCells {
            PhotoGridMetrics.SlottedCells(photoIDs: cells.photoIDs, blankSlotCount: blankSlotCount)
        }
    }

    /// The part of the content on screen: its top, in points in the same
    /// terms scrollTo(y:) takes, and its height in points.
    fileprivate struct VisibleRegion: Equatable {
        let offset: CGFloat
        let height: CGFloat
    }

    /// The scroll view's position, bound to it by `gridScrolling`, so that
    /// GridScrolling can scroll it to an exact offset.
    var position = ScrollPosition()

    /// How many columns the grid has, as last measured.
    private(set) var columnCount = 1

    /// Whether the grid's width has been measured, so columnCount is real.
    private var isMeasured = false

    /// Whether the grid has appeared. The scroll position isn't reported
    /// before then.
    private var hasAppeared = false

    /// Whether the view is moving, by the user or on its own.
    private var isScrolling = false

    /// The part of the content on screen, as last reported by the scroll
    /// view.
    private var visibleRegion = VisibleRegion(offset: 0, height: 0)

    /// The cell behind the next change, if a click or key press came first.
    private var pinnedCell: PinnedCell?

    /// The saved scroll anchor, held from appearing until the user first
    /// scrolls, clicks, or presses a key. Until then it's re-applied whenever
    /// the column count changes (the window may settle on its restored size
    /// after the grid first lays out), and the scroll position isn't
    /// reported, so the default position can't overwrite a saved one.
    private var pendingInitialAnchor: GridScrollAnchor?

    /// Return how many blank slots are actually shown before the first cell.
    func blankSlotCount(for cells: Cells) -> Int {
        PhotoGridMetrics.blankSlotCount(for: cells.leadingBlankSlots, columnCount: columnCount)
    }

    /// Return the value whose changes the scroll view watches.
    func trigger(for cells: Cells) -> Trigger {
        Trigger(cells: cells, blankSlotCount: blankSlotCount(for: cells))
    }

    /// Record the column count once the grid's width is known, and re-apply
    /// the saved scroll position for it.
    func measure(columnCount newColumnCount: Int, cells: Cells) {
        columnCount = newColumnCount
        isMeasured = true
        applyPendingInitialAnchor(cells: cells)
    }

    /// Pin the clicked cell, in case the click changes the cells, and stop
    /// holding the saved scroll position. Call before acting on the click.
    func noteClick(onCellAt index: Int) {
        pinnedCell = PinnedCell(index: index, isFromClick: true)
        pendingInitialAnchor = nil
    }

    /// Mark changes from here on as keyboard-driven: the selection is
    /// followed, and if the cells change, the middle of the view holds
    /// still. Call before acting on the key.
    func noteKeyPress(cells: Cells) {
        pinnedCell = pinForMiddleOfView(cells: cells)
        pendingInitialAnchor = nil
    }

    /// Set the opening scroll position: the saved anchor if there is one
    /// (held until the user takes over; see pendingInitialAnchor),
    /// otherwise the selection, centred.
    fileprivate func appear(cells: Cells, savedAnchor: GridScrollAnchor?, scrollProxy: ScrollViewProxy) {
        hasAppeared = true
        if let savedAnchor, cells.photoIDs.contains(savedAnchor.photoID) {
            pendingInitialAnchor = savedAnchor
            applyPendingInitialAnchor(cells: cells)
        } else if let selectedPhotoID = cells.selectedPhotoID {
            scrollProxy.scrollTo(selectedPhotoID, anchor: .center)
        }
    }

    /// Record the part of the content on screen, reporting the scroll
    /// position unless the view is still moving.
    fileprivate func updateVisibleRegion(
        _ region: VisibleRegion,
        cells: Cells,
        scrollAnchor: Binding<GridScrollAnchor?>
    ) {
        visibleRegion = region
        if !isScrolling {
            reportScrollAnchor(cells: cells, scrollAnchor: scrollAnchor)
        }
    }

    /// Track whether the view is moving, so the scroll position is reported
    /// only once it settles, not on every frame. The user scrolling stops
    /// holding the saved position.
    fileprivate func changePhase(to phase: ScrollPhase, cells: Cells, scrollAnchor: Binding<GridScrollAnchor?>) {
        isScrolling = phase != .idle
        if phase.isUserDriven {
            pendingInitialAnchor = nil
        }
        if !isScrolling {
            reportScrollAnchor(cells: cells, scrollAnchor: scrollAnchor)
        }
    }

    /// Scroll in response to a change, if it calls for it (see
    /// GridScrollResponse). Following the selection uses a nil anchor, so
    /// the view scrolls only as far as needed.
    fileprivate func respondToChange(from old: Trigger, to new: Trigger, scrollProxy: ScrollViewProxy) {
        let response = GridScrollResponse.choose(from: old.cells, to: new.cells, pinnedCell: pinnedCell)
        pinnedCell = nil
        switch response {
        case let .holdCell(heldIndex):
            holdPosition(ofCellAt: heldIndex, across: old, to: new)
        case let .followSelection(selectedPhotoID):
            withAnimation { scrollProxy.scrollTo(selectedPhotoID, anchor: nil) }
        case .stay:
            break
        }
    }

    /// Scroll to the pending initial anchor at the current column count.
    /// Do nothing until the grid has been measured, since the anchor's
    /// position depends on the column count.
    private func applyPendingInitialAnchor(cells: Cells) {
        guard let pendingInitialAnchor, isMeasured,
              let index = cells.photoIDs.firstIndex(of: pendingInitialAnchor.photoID)
        else { return }
        let offset = PhotoGridMetrics.offset(
            forSlot: index + blankSlotCount(for: cells),
            offsetFromRowTop: pendingInitialAnchor.offsetFromRowTop,
            columnCount: columnCount
        )
        position.scrollTo(y: offset)
    }

    /// Write where the view is now to the scroll anchor binding, as the
    /// first cell of the row at the top and how far into that row, in
    /// points, the view has scrolled.
    private func reportScrollAnchor(cells: Cells, scrollAnchor: Binding<GridScrollAnchor?>) {
        guard hasAppeared, pendingInitialAnchor == nil,
              let index = firstCellIndex(inRowAt: visibleRegion.offset, cells: cells)
        else { return }
        let rowTop = PhotoGridMetrics.rowTop(forSlot: index + blankSlotCount(for: cells), columnCount: columnCount)
        let anchor = GridScrollAnchor(photoID: cells.photoIDs[index], offsetFromRowTop: visibleRegion.offset - rowTop)
        // Repeats are skipped so that whatever the binding writes to (such
        // as observed state that gets saved) only changes when the view has.
        guard anchor != scrollAnchor.wrappedValue else { return }
        scrollAnchor.wrappedValue = anchor
    }

    /// Return the index of the first cell in the row at a height, in points,
    /// within the content, clamped to the cells so that blank slots and
    /// space past the end land on the nearest cell. Return nil when there
    /// are no cells.
    private func firstCellIndex(inRowAt height: CGFloat, cells: Cells) -> Int? {
        guard !cells.photoIDs.isEmpty else { return nil }
        let slot = PhotoGridMetrics.firstSlot(inRowAt: height, columnCount: columnCount)
        return min(max(0, slot - blankSlotCount(for: cells)), cells.photoIDs.count - 1)
    }

    /// Scroll so that a cell from before the change, or if it has gone its
    /// nearest survivor, is at the same height on screen as before. Without
    /// the scroll, collapsing groups above the view would carry the view
    /// forward.
    private func holdPosition(ofCellAt heldIndex: Int, across old: Trigger, to new: Trigger) {
        guard let offset = PhotoGridMetrics.scrollOffsetHoldingCell(
            at: heldIndex,
            from: old.slottedCells,
            to: new.slottedCells,
            columnCount: columnCount,
            currentOffset: visibleRegion.offset
        )
        else { return }
        position.scrollTo(y: offset)
    }

    /// Return a pin on the first cell of the row in the middle of the view,
    /// or nil when there are no cells.
    private func pinForMiddleOfView(cells: Cells) -> PinnedCell? {
        let middle = visibleRegion.offset + visibleRegion.height / 2
        return firstCellIndex(inRowAt: middle, cells: cells).map { index in
            PinnedCell(index: index, isFromClick: false)
        }
    }
}

extension View {
    /// Attach a GridScrolling to this scroll view: bind its scroll position,
    /// feed it scroll geometry and phase changes and changes to the cells,
    /// and set the opening position on appear. The scroll
    /// position is read from `scrollAnchor` on appear and written back to it
    /// as the view settles.
    func gridScrolling(
        _ scrolling: GridScrolling,
        cells: GridScrolling.Cells,
        scrollAnchor: Binding<GridScrollAnchor?>,
        scrollProxy: ScrollViewProxy
    ) -> some View {
        @Bindable var scrolling = scrolling
        return scrollPosition($scrolling.position)
            // The reported offset counts from under the toolbar (it starts
            // at minus the top inset), while scrollTo(y:) counts from the
            // top of the content; adding the inset converts one to the other.
            .onScrollGeometryChange(for: GridScrolling.VisibleRegion.self) { geometry in
                GridScrolling.VisibleRegion(
                    offset: geometry.contentOffset.y + geometry.contentInsets.top,
                    height: geometry.containerSize.height - geometry.contentInsets.top
                )
            } action: { _, region in
                scrolling.updateVisibleRegion(region, cells: cells, scrollAnchor: scrollAnchor)
            }
            .onScrollPhaseChange { _, phase in
                scrolling.changePhase(to: phase, cells: cells, scrollAnchor: scrollAnchor)
            }
            .onChange(of: scrolling.trigger(for: cells)) { old, new in
                scrolling.respondToChange(from: old, to: new, scrollProxy: scrollProxy)
            }
            .onAppear {
                scrolling.appear(cells: cells, savedAnchor: scrollAnchor.wrappedValue, scrollProxy: scrollProxy)
            }
    }
}

extension ScrollPhase {
    /// Whether the user is moving the view themselves (dragging, flicking,
    /// or the scroll that follows), as opposed to it moving on its own.
    var isUserDriven: Bool {
        switch self {
        case .tracking, .interacting, .decelerating: true
        case .idle, .animating: false
        @unknown default: false
        }
    }
}
