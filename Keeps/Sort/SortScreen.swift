import AppKit
import SwiftUI

/// The sort screen, where the folder is split into groups: a lazy scrolling
/// grid with one cell per photo or collapsed group. Clicking the edge of a
/// cell toggles the boundary in that gap, and clicking its middle selects it.
/// Arrow and h/j/k/l keys move the selection, Escape clears it, and C
/// collapses every group closed so far.
///
/// Also owns the grid geometry (column math), keyboard focus, and scrolling:
/// holding the working point still as groups collapse, restoring the saved
/// scroll position, following keyboard selection, and reporting the scroll
/// position to the grouping. The grouping itself lives in Grouping.
struct SortScreen: View {
    @Bindable var grouping: Grouping

    /// The gap under the pointer, or nil when the pointer is not over a gap.
    @State private var hoveredGap: Int?

    @State private var columnCount: Int = 1
    @FocusState private var isFocused: Bool
    @State private var scrollPosition = ScrollPosition()
    @State private var visibleRegion = VisibleRegion(offset: 0, height: 0)
    @State private var pinnedItem: PinnedItem?
    @State private var isScrolling = false

    /// Whether the grid's width has been measured, so columnCount is real.
    @State private var isMeasured = false

    @State private var hasAppeared = false

    /// The saved scroll anchor, held from appearing until the user first
    /// scrolls, clicks, or presses a key. Until then it's re-applied whenever
    /// the column count changes (the window may settle on its restored size
    /// after the grid first lays out), and the scroll position isn't
    /// reported, so the default position can't overwrite a saved one.
    @State private var pendingInitialAnchor: GridScrollAnchor?

    /// The part of the content on screen: its top, in the same terms
    /// scrollTo(y:) takes, and its height.
    private struct VisibleRegion: Equatable {
        let offset: CGFloat
        let height: CGFloat
    }

    /// The input behind the next change: a click pins the clicked cell, a
    /// key press the cell in the middle of the view. Used to hold the view
    /// still when there's no working point, and to tell click-driven
    /// selection changes (which don't scroll) from keyboard ones (which do).
    private struct PinnedItem {
        let index: Int
        let isFromClick: Bool
    }

    /// The state whose changes may call for a scroll.
    private struct ScrollTrigger: Equatable {
        let itemIDs: [UUID]
        let selectedItemID: UUID?
        let stableItemID: UUID?
        let blankSlotCount: Int
    }

    private static var cellSize: CGFloat {
        PhotoGridMetrics.cellSize
    }

    private static var spacing: CGFloat {
        PhotoGridMetrics.spacing
    }

    /// The width each cell occupies: the cell plus half the gap on either
    /// side. Cells own their share of the gap so that clicks and hovers
    /// there land on a cell instead of falling through, so the grid itself
    /// has no horizontal spacing.
    private static var slotWidth: CGFloat {
        cellSize + spacing
    }

    /// The blank slots shown before the first cell. Collapsing removes cells
    /// ahead of the open photos; matching blanks keep those photos in their
    /// original columns.
    private var blankSlotCount: Int {
        PhotoGridMetrics.blankSlotCount(for: grouping.layout.hiddenPhotoCount, columnCount: columnCount)
    }

    /// The photo shown by the selected cell.
    private var selectedItemID: UUID? {
        grouping.selectedCellIndex.map { grouping.cellItems[$0].id }
    }

    /// The photo to keep at the same height on screen whenever the cells
    /// change: where grouping has reached. When nil, the cell the user last
    /// clicked, or the middle of the view after a key press, is held
    /// instead.
    private var stableItemID: UUID? {
        grouping.workingPointPhotoIndex.map { grouping.items[$0].id }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: Self.slotWidth, maximum: Self.slotWidth), spacing: 0)]
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                grid
            }
            .scrollPosition($scrollPosition)
            // The reported offset counts from under the toolbar (it starts
            // at minus the top inset), while scrollTo(y:) counts from the
            // top of the content; adding the inset converts one to the other.
            .onScrollGeometryChange(for: VisibleRegion.self) { geometry in
                VisibleRegion(
                    offset: geometry.contentOffset.y + geometry.contentInsets.top,
                    height: geometry.containerSize.height - geometry.contentInsets.top
                )
            } action: { _, region in
                visibleRegion = region
                if !isScrolling {
                    reportScrollAnchor()
                }
            }
            // Reported only once scrolling settles, not on every frame.
            .onScrollPhaseChange { _, phase in
                isScrolling = phase != .idle
                if phase.isUserDriven {
                    pendingInitialAnchor = nil
                }
                if !isScrolling {
                    reportScrollAnchor()
                }
            }
            .onChange(of: ScrollTrigger(
                itemIDs: grouping.cellItems.map(\.id),
                selectedItemID: selectedItemID,
                stableItemID: stableItemID,
                blankSlotCount: blankSlotCount
            )) { old, new in
                respondToChange(from: old, to: new, scrollProxy: scrollProxy)
            }
            .focusable()
            .focusEffectDisabled()
            .focused($isFocused)
            .onKeyPress { press in
                handleKeyPress(press) ? .handled : .ignored
            }
            .onAppear {
                isFocused = true
                handleAppear(scrollProxy: scrollProxy)
            }
        }
    }

    /// Sets the opening scroll position: the saved anchor if there is one
    /// (held until the user takes over; see pendingInitialAnchor),
    /// otherwise the selection, centred.
    private func handleAppear(scrollProxy: ScrollViewProxy) {
        hasAppeared = true
        if let initialAnchor = grouping.scrollAnchor,
           grouping.cellItems.contains(where: { $0.id == initialAnchor.itemID })
        {
            pendingInitialAnchor = initialAnchor
            applyPendingInitialAnchor()
        } else if let selectedItemID {
            scrollProxy.scrollTo(selectedItemID, anchor: .center)
        }
    }

    /// Scrolls to the pending initial anchor at the current column count.
    /// Does nothing until the grid has been measured, since the anchor's
    /// position depends on the column count.
    private func applyPendingInitialAnchor() {
        guard let pendingInitialAnchor, isMeasured,
              let index = grouping.cellItems.firstIndex(where: { $0.id == pendingInitialAnchor.itemID })
        else { return }
        let offset = PhotoGridMetrics.offset(
            forSlot: index + blankSlotCount,
            offsetFromRowTop: pendingInitialAnchor.offsetFromRowTop,
            columnCount: columnCount
        )
        scrollPosition.scrollTo(y: offset)
    }

    /// Writes where the view is now to the grouping's scroll anchor, as the
    /// first cell of the row at the top and how far into that row the view
    /// has scrolled.
    private func reportScrollAnchor() {
        guard hasAppeared, pendingInitialAnchor == nil,
              let index = firstCellIndex(inRowAt: visibleRegion.offset)
        else { return }
        let rowTop = PhotoGridMetrics.rowTop(forIndex: index + blankSlotCount, columnCount: columnCount)
        let anchor = GridScrollAnchor(itemID: grouping.cellItems[index].id, offsetFromRowTop: visibleRegion.offset - rowTop)
        // Repeats are skipped so that the grouping, which is saved whenever
        // it changes, only changes when the view has.
        guard anchor != grouping.scrollAnchor else { return }
        grouping.scrollAnchor = anchor
    }

    /// The index of the first cell in the row at a height within the
    /// content, clamped to the cells so that blank slots and space past the
    /// end land on the nearest cell. Nil when there are no cells.
    private func firstCellIndex(inRowAt height: CGFloat) -> Int? {
        let cellCount = grouping.layout.cells.count
        guard cellCount > 0 else { return nil }
        let slot = PhotoGridMetrics.firstSlot(inRowAt: height, columnCount: columnCount)
        return min(max(0, slot - blankSlotCount), cellCount - 1)
    }

    /// The lazy grid of cells, measuring its own width for the column count.
    private var grid: some View {
        // Found once per render rather than once per cell, since finding
        // the selected cell searches the whole layout.
        let layout = grouping.layout
        let selectedCellIndex = grouping.selectedCellIndex
        return LazyVGrid(columns: columns, spacing: Self.spacing) {
            ForEach(0 ..< blankSlotCount, id: \.self) { _ in
                Color.clear.frame(width: Self.slotWidth, height: Self.cellSize)
            }
            ForEach(Array(grouping.cellItems.enumerated()), id: \.element.id) { index, item in
                interactiveCell(item: item, index: index, isSelected: index == selectedCellIndex, layout: layout)
            }
        }
        // Measured inside the padding: the adaptive grid computes its
        // column count from this same unpadded width, so measuring the
        // padded view would over-count columns at some window widths.
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            columnCount = max(1, Int(width / Self.slotWidth))
            isMeasured = true
            applyPendingInitialAnchor()
        }
        // Horizontally, each slot already carries half a gap.
        .padding(.vertical, Self.spacing)
        .padding(.horizontal, Self.spacing / 2)
    }

    /// Scrolls in response to a change, if it calls for it. When the cells
    /// change, the view is held still — around the working point if there
    /// is one, otherwise the pinned cell — and the selection isn't chased.
    /// When the selection changes, it's followed unless a click caused it
    /// (the clicked cell is already on screen), with a nil anchor so it
    /// scrolls only as far as needed.
    private func respondToChange(from old: ScrollTrigger, to new: ScrollTrigger, scrollProxy: ScrollViewProxy) {
        let pin = pinnedItem
        pinnedItem = nil
        if old.itemIDs != new.itemIDs {
            holdPosition(across: old, to: new, pin: pin)
        } else if old.selectedItemID != new.selectedItemID, pin?.isFromClick != true, let id = new.selectedItemID {
            withAnimation { scrollProxy.scrollTo(id, anchor: nil) }
        }
    }

    /// Scrolls so that the held cell — the working point from before the
    /// change, else the pinned cell, else (if it has gone) its nearest
    /// survivor — is at the same height on screen as before. Without this,
    /// collapsing groups above the view would carry it forward.
    private func holdPosition(across old: ScrollTrigger, to new: ScrollTrigger, pin: PinnedItem?) {
        let stableIndex = old.stableItemID.flatMap { old.itemIDs.firstIndex(of: $0) }
        guard let heldIndex = stableIndex ?? pin?.index,
              let offset = PhotoGridMetrics.scrollOffsetHoldingItem(
                  at: heldIndex,
                  oldIDs: old.itemIDs,
                  newIDs: new.itemIDs,
                  oldBlankSlots: old.blankSlotCount,
                  newBlankSlots: new.blankSlotCount,
                  columnCount: columnCount,
                  currentOffset: visibleRegion.offset
              )
        else { return }
        scrollPosition.scrollTo(y: offset)
    }

    /// A pin on the first cell of the row in the middle of the view, for
    /// changes that come from the keyboard rather than a click.
    private func pinForMiddleOfView() -> PinnedItem? {
        let middle = visibleRegion.offset + visibleRegion.height / 2
        return firstCellIndex(inRowAt: middle).map { PinnedItem(index: $0, isFromClick: false) }
    }

    /// One cell, widened to fill its slot, with click and hover handling
    /// attached.
    private func interactiveCell(item: PhotoItem, index: Int, isSelected: Bool, layout: GroupLayout) -> some View {
        SortCell(
            item: item,
            isSelected: isSelected,
            leadingBoundary: boundaryStyle(atGap: index, in: layout),
            trailingBoundary: boundaryStyle(atGap: index + 1, in: layout),
            collapsedPhotos: collapsedPhotos(ofCell: index, in: layout)
        )
        .padding(.horizontal, Self.spacing / 2)
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in
            handleTap(at: location, index: index)
        }
        .onContinuousHover { phase in
            updateHoveredGap(for: phase, index: index)
        }
        .id(item.id)
    }

    /// The photos in a cell's group if it is collapsed, or nil for a single
    /// photo.
    private func collapsedPhotos(ofCell cellIndex: Int, in layout: GroupLayout) -> ArraySlice<PhotoItem>? {
        let cell = layout.cells[cellIndex]
        return cell.isCollapsed ? grouping.items[cell.photoRange] : nil
    }

    /// How to draw the bar at a gap: nothing at a locked gap, placed if
    /// there is a boundary there, previewed if the pointer is over it.
    private func boundaryStyle(atGap gapIndex: Int, in layout: GroupLayout) -> SortCell.BoundaryStyle? {
        guard layout.isGapEditable(gapIndex) else { return nil }
        if layout.hasBoundary(atGap: gapIndex) {
            return .placed
        }
        return gapIndex == hoveredGap ? .preview : nil
    }

    /// Records the gap under the pointer in the slot at `index`, if it has
    /// changed.
    private func updateHoveredGap(for phase: HoverPhase, index: Int) {
        let gapIndex: Int? = switch phase {
        case let .active(location): hitTarget(at: location, index: index).gapIndex
        case .ended: nil
        }
        guard gapIndex != hoveredGap else { return }
        hoveredGap = gapIndex
    }

    /// Toggles the boundary at a clicked gap, or selects a clicked cell, then
    /// takes keyboard focus. Pins the clicked cell first, in case the click
    /// changes the cells.
    private func handleTap(at location: CGPoint, index: Int) {
        pinnedItem = PinnedItem(index: index, isFromClick: true)
        pendingInitialAnchor = nil
        switch hitTarget(at: location, index: index) {
        case let .gap(gapIndex):
            grouping.toggleBoundary(atGap: gapIndex)
        case .item:
            grouping.selectCell(at: index)
        }
        isFocused = true
    }

    /// What a point within the slot at `index` targets: the cell, or the gap
    /// at one of its edges.
    private func hitTarget(at location: CGPoint, index: Int) -> GridHitTarget {
        GridHitTarget.resolve(offset: location.x, cellWidth: Self.slotWidth, index: index)
    }

    private enum Direction { case left, right, up, down }

    /// Moves the selection for spatial keys using the current column count,
    /// and handles the other keys the screen knows.
    private func handleKeyPress(_ press: KeyPress) -> Bool {
        // Changes from here on are keyboard-driven: the selection is
        // followed, and if the cells change, the middle of the view holds
        // still.
        pinnedItem = pinForMiddleOfView()
        pendingInitialAnchor = nil
        let cellCount = grouping.layout.cells.count
        guard let direction = direction(for: press),
              cellCount > 0,
              let current = grouping.selectedCellIndex
        else { return handleCommandKey(press) }
        let targetIndex = switch direction {
        case .left: max(0, current - 1)
        case .right: min(cellCount - 1, current + 1)
        case .up: current - columnCount >= 0 ? current - columnCount : current
        case .down: current + columnCount < cellCount ? current + columnCount : current
        }
        grouping.selectCell(at: targetIndex)
        return true
    }

    /// Handles keys that aren't for moving the selection: Escape clears the
    /// selection, and C collapses every group closed so far. Returns false
    /// for any other key.
    private func handleCommandKey(_ press: KeyPress) -> Bool {
        if press.key == .escape {
            grouping.clearSelection()
            return true
        }
        let hasModifiers = !press.modifiers.intersection([.command, .control, .option]).isEmpty
        if !hasModifiers, press.characters.lowercased() == "c" {
            grouping.collapseClosedGroups()
            return true
        }
        return false
    }

    /// The direction an arrow key or vi key (h/j/k/l) moves in, or nil for
    /// any other key.
    private func direction(for press: KeyPress) -> Direction? {
        switch press.key {
        case .leftArrow: return .left
        case .rightArrow: return .right
        case .downArrow: return .down
        case .upArrow: return .up
        default: break
        }
        // Lowercased so the keys still work with Caps Lock on.
        switch press.characters.lowercased() {
        case "h": return .left
        case "l": return .right
        case "j": return .down
        case "k": return .up
        default: return nil
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
