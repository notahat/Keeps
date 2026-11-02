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
/// anything or handle input itself. The geometry it works from is in
/// PhotoGridMetrics.
@Observable
final class GridScrolling {
    /// What the grid is showing, as far as scrolling cares.
    struct Cells: Equatable {
        /// The photo each cell shows, in order.
        let itemIDs: [UUID]
        let selectedItemID: UUID?

        /// A photo to keep at the same height on screen whenever the cells
        /// change, such as the working point. When nil, the cell the user
        /// last clicked, or the middle of the view after a key press, is
        /// held instead.
        let stableItemID: UUID?

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
    }

    /// The part of the content on screen: its top, in the same terms
    /// scrollTo(y:) takes, and its height.
    fileprivate struct VisibleRegion: Equatable {
        let offset: CGFloat
        let height: CGFloat
    }

    /// The input behind the next change: a click pins the clicked cell, a
    /// key press the cell in the middle of the view. Used to hold the view
    /// still when there's no stable item, and to tell click-driven
    /// selection changes (which don't scroll) from keyboard ones (which do).
    private struct PinnedItem {
        let index: Int
        let isFromClick: Bool
    }

    /// The scroll view's position, bound to it by `gridScrolling`, so that
    /// GridScrolling can scroll it to an exact offset.
    var position = ScrollPosition()

    /// How many columns the grid has, as last measured.
    private(set) var columnCount = 1

    /// Whether the grid's width has been measured, so columnCount is real.
    private var isMeasured = false

    private var hasAppeared = false
    private var isScrolling = false
    private var visibleRegion = VisibleRegion(offset: 0, height: 0)
    private var pinnedItem: PinnedItem?

    /// The saved scroll anchor, held from appearing until the user first
    /// scrolls, clicks, or presses a key. Until then it's re-applied whenever
    /// the column count changes (the window may settle on its restored size
    /// after the grid first lays out), and the scroll position isn't
    /// reported, so the default position can't overwrite a saved one.
    private var pendingInitialAnchor: GridScrollAnchor?

    /// The blank slots actually shown before the first cell.
    func blankSlotCount(for cells: Cells) -> Int {
        PhotoGridMetrics.blankSlotCount(for: cells.leadingBlankSlots, columnCount: columnCount)
    }

    /// The value whose changes the scroll view watches.
    func trigger(for cells: Cells) -> Trigger {
        Trigger(cells: cells, blankSlotCount: blankSlotCount(for: cells))
    }

    /// Records the column count once the grid's width is known, and re-applies
    /// the saved scroll position for it.
    func measure(columnCount newColumnCount: Int, cells: Cells) {
        columnCount = newColumnCount
        isMeasured = true
        applyPendingInitialAnchor(cells: cells)
    }

    /// Pins the clicked cell, in case the click changes the cells, and stops
    /// holding the saved scroll position. Call before acting on the click.
    func noteClick(onCellAt index: Int) {
        pinnedItem = PinnedItem(index: index, isFromClick: true)
        pendingInitialAnchor = nil
    }

    /// Marks changes from here on as keyboard-driven: the selection is
    /// followed, and if the cells change, the middle of the view holds
    /// still. Call before acting on the key.
    func noteKeyPress(cells: Cells) {
        pinnedItem = pinForMiddleOfView(cells: cells)
        pendingInitialAnchor = nil
    }

    /// Sets the opening scroll position: the saved anchor if there is one
    /// (held until the user takes over; see pendingInitialAnchor),
    /// otherwise the selection, centred.
    fileprivate func appear(cells: Cells, savedAnchor: GridScrollAnchor?, scrollProxy: ScrollViewProxy) {
        hasAppeared = true
        if let savedAnchor, cells.itemIDs.contains(savedAnchor.itemID) {
            pendingInitialAnchor = savedAnchor
            applyPendingInitialAnchor(cells: cells)
        } else if let selectedItemID = cells.selectedItemID {
            scrollProxy.scrollTo(selectedItemID, anchor: .center)
        }
    }

    /// Records the part of the content on screen, reporting the scroll
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

    /// Tracks whether the view is moving, so the scroll position is reported
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

    /// Scrolls in response to a change, if it calls for it. When the cells
    /// change, the view is held still — around the stable item if there is
    /// one, otherwise the pinned cell — and the selection isn't chased.
    /// When the selection changes, it's followed unless a click caused it
    /// (the clicked cell is already on screen), with a nil anchor so it
    /// scrolls only as far as needed.
    fileprivate func respondToChange(from old: Trigger, to new: Trigger, scrollProxy: ScrollViewProxy) {
        let pin = pinnedItem
        pinnedItem = nil
        if old.cells.itemIDs != new.cells.itemIDs {
            holdPosition(across: old, to: new, pin: pin)
        } else if old.cells.selectedItemID != new.cells.selectedItemID,
                  pin?.isFromClick != true,
                  let id = new.cells.selectedItemID
        {
            withAnimation { scrollProxy.scrollTo(id, anchor: nil) }
        }
    }

    /// Scrolls to the pending initial anchor at the current column count.
    /// Does nothing until the grid has been measured, since the anchor's
    /// position depends on the column count.
    private func applyPendingInitialAnchor(cells: Cells) {
        guard let pendingInitialAnchor, isMeasured,
              let index = cells.itemIDs.firstIndex(of: pendingInitialAnchor.itemID)
        else { return }
        let offset = PhotoGridMetrics.offset(
            forSlot: index + blankSlotCount(for: cells),
            offsetFromRowTop: pendingInitialAnchor.offsetFromRowTop,
            columnCount: columnCount
        )
        position.scrollTo(y: offset)
    }

    /// Writes where the view is now to the scroll anchor binding, as the
    /// first cell of the row at the top and how far into that row the view
    /// has scrolled.
    private func reportScrollAnchor(cells: Cells, scrollAnchor: Binding<GridScrollAnchor?>) {
        guard hasAppeared, pendingInitialAnchor == nil,
              let index = firstCellIndex(inRowAt: visibleRegion.offset, cells: cells)
        else { return }
        let rowTop = PhotoGridMetrics.rowTop(forIndex: index + blankSlotCount(for: cells), columnCount: columnCount)
        let anchor = GridScrollAnchor(itemID: cells.itemIDs[index], offsetFromRowTop: visibleRegion.offset - rowTop)
        // Repeats are skipped so that whatever the binding writes to (such
        // as observed state that gets saved) only changes when the view has.
        guard anchor != scrollAnchor.wrappedValue else { return }
        scrollAnchor.wrappedValue = anchor
    }

    /// The index of the first cell in the row at a height within the
    /// content, clamped to the cells so that blank slots and space past the
    /// end land on the nearest cell. Nil when there are no cells.
    private func firstCellIndex(inRowAt height: CGFloat, cells: Cells) -> Int? {
        guard !cells.itemIDs.isEmpty else { return nil }
        let slot = PhotoGridMetrics.firstSlot(inRowAt: height, columnCount: columnCount)
        return min(max(0, slot - blankSlotCount(for: cells)), cells.itemIDs.count - 1)
    }

    /// Scrolls so that the held cell — the stable item from before the
    /// change, else the pinned cell, else (if it has gone) its nearest
    /// survivor — is at the same height on screen as before. Without this,
    /// collapsing groups above the view would carry it forward.
    private func holdPosition(across old: Trigger, to new: Trigger, pin: PinnedItem?) {
        let stableIndex = old.cells.stableItemID.flatMap { old.cells.itemIDs.firstIndex(of: $0) }
        guard let heldIndex = stableIndex ?? pin?.index,
              let offset = PhotoGridMetrics.scrollOffsetHoldingItem(
                  at: heldIndex,
                  oldIDs: old.cells.itemIDs,
                  newIDs: new.cells.itemIDs,
                  oldBlankSlots: old.blankSlotCount,
                  newBlankSlots: new.blankSlotCount,
                  columnCount: columnCount,
                  currentOffset: visibleRegion.offset
              )
        else { return }
        position.scrollTo(y: offset)
    }

    /// A pin on the first cell of the row in the middle of the view.
    private func pinForMiddleOfView(cells: Cells) -> PinnedItem? {
        let middle = visibleRegion.offset + visibleRegion.height / 2
        return firstCellIndex(inRowAt: middle, cells: cells).map { PinnedItem(index: $0, isFromClick: false) }
    }
}

extension View {
    /// Attaches a GridScrolling to this scroll view: binds its scroll
    /// position, feeds it scroll geometry and phase changes and changes to
    /// the cells, and sets the opening position on appear. The scroll
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
