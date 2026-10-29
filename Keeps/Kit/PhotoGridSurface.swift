import AppKit
import SwiftUI

/// A lazy scrolling grid of photo cells. Owns the grid geometry (column
/// math), scroll-to-selection, keyboard focus, the interpretation of spatial
/// navigation keys (arrows and h/j/k/l) into NavigationProposals, and —
/// when the caller asks for it — resolving clicks and hovers on cell edges
/// into gaps between items (see GridHitTarget). All policy — what a proposal
/// does to the selection, what any other key or a gap click means — belongs
/// to the caller, as does the cell content. Knows nothing about marks,
/// filters, groups, or any other workflow concept.
struct PhotoGridSurface<Cell: View>: View {
    var items: [PhotoItem]
    var selectedIndex: Int?
    var onNavigate: (NavigationProposal) -> Void

    /// Receives every key press that isn't a spatial navigation key.
    /// Returns true when the key was handled.
    var onKeyDown: (NSEvent) -> Bool

    var onTap: (_ index: Int, _ extendsRange: Bool) -> Void
    var onDoubleTap: (_ index: Int) -> Void

    /// Receives clicks on a gap, identified by the index of the item after
    /// it. When nil, cell edges behave like the rest of the cell.
    var onGapTap: ((_ gapIndex: Int) -> Void)?

    /// The gap under the pointer, or nil when the pointer is not over a gap.
    /// Written as the pointer moves, only when it changes, and only when
    /// onGapTap is set, since otherwise there are no gaps to hover.
    var hoveredGap: Binding<Int?> = .constant(nil)

    /// Empty slots to leave before the first item. Only the remainder by the
    /// column count is used, so a caller that removes items from the front
    /// of the list can pass the running total removed to keep the remaining
    /// items in their original columns.
    var leadingBlankSlots: Int = 0

    /// An item to keep at the same height on screen whenever the items
    /// change, such as the point the user is working from. When nil, the
    /// item the user last clicked, or the middle of the view after a key
    /// press, is held instead.
    var stableItemID: UUID?

    /// The scroll position. Read once when the grid first lays out, to
    /// restore a position such as one saved from a previous session; when
    /// nil then, the grid instead centres the selection. Written whenever
    /// scrolling settles (when the user stops scrolling, and after the grid
    /// moves itself), but only when the position has actually changed.
    var scrollAnchor: Binding<GridScrollAnchor?> = .constant(nil)

    @ViewBuilder var cell: (_ item: PhotoItem, _ index: Int) -> Cell

    @State private var columnCount: Int = 1
    @State private var keyView: KeyAwareView.ResponderView?
    @State private var scrollPosition = ScrollPosition()
    @State private var visibleRegion = VisibleRegion(offset: 0, height: 0)
    @State private var pinnedItem: PinnedItem?
    @State private var isScrolling = false

    /// Whether the grid's width has been measured, so columnCount is real.
    @State private var isMeasured = false

    @State private var hasAppeared = false

    /// The initial scroll anchor, held from appearing until the user first
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

    /// The input behind the next change: a click pins the clicked item, a
    /// key press the item in the middle of the view. Used to hold the view
    /// still when there's no stable item, and to tell click-driven selection
    /// changes (which don't scroll) from keyboard ones (which do).
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

    /// The blank slots actually shown before the first item.
    private var blankSlotCount: Int {
        PhotoGridMetrics.blankSlotCount(for: leadingBlankSlots, columnCount: columnCount)
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

    /// The identity of the selected item, if the selection is in range.
    private var selectedItemID: UUID? {
        guard let selectedIndex, items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex].id
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
                itemIDs: items.map(\.id),
                selectedItemID: selectedItemID,
                stableItemID: stableItemID,
                blankSlotCount: blankSlotCount
            )) { old, new in
                respondToChange(from: old, to: new, scrollProxy: scrollProxy)
            }
            .background {
                KeyAwareView(onKeyDown: { event in handleKeyEvent(event) }, onViewReady: { keyView = $0 })
            }
            .onAppear {
                handleAppear(scrollProxy: scrollProxy)
            }
        }
    }

    /// Sets the opening scroll position: the initial anchor if there is one
    /// (held until the user takes over; see pendingInitialAnchor),
    /// otherwise the selection, centred.
    private func handleAppear(scrollProxy: ScrollViewProxy) {
        hasAppeared = true
        if let initialAnchor = scrollAnchor.wrappedValue,
           items.contains(where: { $0.id == initialAnchor.itemID })
        {
            pendingInitialAnchor = initialAnchor
            applyPendingInitialAnchor()
        } else if let selectedIndex {
            scrollProxy.scrollTo(items[selectedIndex].id, anchor: .center)
        }
    }

    /// Scrolls to the pending initial anchor at the current column count.
    /// Does nothing until the grid has been measured, since the anchor's
    /// position depends on the column count.
    private func applyPendingInitialAnchor() {
        guard let pendingInitialAnchor, isMeasured,
              let index = items.firstIndex(where: { $0.id == pendingInitialAnchor.itemID })
        else { return }
        let offset = PhotoGridMetrics.offset(
            forSlot: index + blankSlotCount,
            offsetFromRowTop: pendingInitialAnchor.offsetFromRowTop,
            columnCount: columnCount
        )
        scrollPosition.scrollTo(y: offset)
    }

    /// Writes where the view is now to the scroll anchor binding, as the
    /// first item of the row at the top and how far into that row the view
    /// has scrolled.
    private func reportScrollAnchor() {
        guard hasAppeared, pendingInitialAnchor == nil,
              let index = firstItemIndex(inRowAt: visibleRegion.offset)
        else { return }
        let rowTop = PhotoGridMetrics.rowTop(forIndex: index + blankSlotCount, columnCount: columnCount)
        let anchor = GridScrollAnchor(itemID: items[index].id, offsetFromRowTop: visibleRegion.offset - rowTop)
        // Repeats are skipped so that whatever the binding writes to (such
        // as observed state that gets saved) only changes when the view has.
        guard anchor != scrollAnchor.wrappedValue else { return }
        scrollAnchor.wrappedValue = anchor
    }

    /// The index of the first item in the row at a height within the
    /// content, clamped to the items so that blank slots and space past the
    /// end land on the nearest item. Nil when there are no items.
    private func firstItemIndex(inRowAt height: CGFloat) -> Int? {
        guard !items.isEmpty else { return nil }
        let slot = PhotoGridMetrics.firstSlot(inRowAt: height, columnCount: columnCount)
        return min(max(0, slot - blankSlotCount), items.count - 1)
    }

    /// The lazy grid of cells, measuring its own width for the column count.
    private var grid: some View {
        LazyVGrid(columns: columns, spacing: Self.spacing) {
            ForEach(0 ..< blankSlotCount, id: \.self) { _ in
                Color.clear.frame(width: Self.slotWidth, height: Self.cellSize)
            }
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                interactiveCell(item: item, index: index)
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

    /// Scrolls in response to a change, if it calls for it. When the items
    /// change, the view is held still — around the stable item if there is
    /// one, otherwise the pinned one — and the selection isn't chased. When
    /// the selection changes, it's followed unless a click caused it (the
    /// clicked item is already on screen), with a nil anchor so it scrolls
    /// only as far as needed.
    private func respondToChange(from old: ScrollTrigger, to new: ScrollTrigger, scrollProxy: ScrollViewProxy) {
        let pin = pinnedItem
        pinnedItem = nil
        if old.itemIDs != new.itemIDs {
            holdPosition(across: old, to: new, pin: pin)
        } else if old.selectedItemID != new.selectedItemID, pin?.isFromClick != true, let id = new.selectedItemID {
            withAnimation { scrollProxy.scrollTo(id, anchor: nil) }
        }
    }

    /// Scrolls so that the held item — the stable item from before the
    /// change, else the pinned one, else (if it has gone) its nearest
    /// survivor — is at the same height on screen as before. Without this,
    /// removing cells above the view would carry it forward.
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

    /// A pin on the first item of the row in the middle of the view, for
    /// changes that come from the keyboard rather than a click.
    private func pinForMiddleOfView() -> PinnedItem? {
        let middle = visibleRegion.offset + visibleRegion.height / 2
        return firstItemIndex(inRowAt: middle).map { PinnedItem(index: $0, isFromClick: false) }
    }

    /// The caller's cell, widened to fill its slot, with click,
    /// double-click, and hover handling attached.
    private func interactiveCell(item: PhotoItem, index: Int) -> some View {
        cell(item, index)
            .padding(.horizontal, Self.spacing / 2)
            .contentShape(Rectangle())
            .onTapGesture(count: 2, coordinateSpace: .local) { location in
                if case .item = hitTarget(at: location, index: index) {
                    onDoubleTap(index)
                }
            }
            // simultaneousGesture fires immediately without waiting for the
            // double-tap timeout that onTapGesture(count: 1) would incur.
            .simultaneousGesture(SpatialTapGesture().onEnded { value in
                handleTap(at: value.location, index: index)
            })
            .onContinuousHover { phase in
                updateHoveredGap(for: phase, index: index)
            }
            .id(item.id)
    }

    /// Writes the gap under the pointer in the slot at `index` to the
    /// hovered gap binding, if gaps are enabled and it has changed.
    private func updateHoveredGap(for phase: HoverPhase, index: Int) {
        guard onGapTap != nil else { return }
        let gapIndex: Int? = switch phase {
        case let .active(location): hitTarget(at: location, index: index).gapIndex
        case .ended: nil
        }
        guard gapIndex != hoveredGap.wrappedValue else { return }
        hoveredGap.wrappedValue = gapIndex
    }

    /// Routes a single click to onGapTap or onTap, then takes keyboard focus.
    /// Pins the clicked item first, in case the caller reshapes the items.
    private func handleTap(at location: CGPoint, index: Int) {
        pinnedItem = PinnedItem(index: index, isFromClick: true)
        pendingInitialAnchor = nil
        switch hitTarget(at: location, index: index) {
        case let .gap(gapIndex):
            onGapTap?(gapIndex)
        case .item:
            let isShiftHeld = NSApp.currentEvent?.modifierFlags.contains(.shift) == true
            onTap(index, isShiftHeld)
        }
        keyView?.window?.makeFirstResponder(keyView)
    }

    /// What a point within the slot at `index` targets. Edges only count as
    /// gaps when the caller handles gap clicks.
    private func hitTarget(at location: CGPoint, index: Int) -> GridHitTarget {
        guard onGapTap != nil else { return .item(index) }
        return GridHitTarget.resolve(offset: location.x, cellWidth: Self.slotWidth, index: index)
    }

    private enum Direction { case left, right, up, down }

    /// Turns spatial keys into NavigationProposals using the current column
    /// count; forwards everything else to onKeyDown.
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Changes from here on are keyboard-driven: the selection is
        // followed, and if the items change, the middle of the view holds
        // still.
        pinnedItem = pinForMiddleOfView()
        pendingInitialAnchor = nil
        guard let direction = direction(for: event),
              !items.isEmpty,
              let current = selectedIndex
        else { return onKeyDown(event) }
        let count = items.count
        let targetIndex = switch direction {
        case .left: max(0, current - 1)
        case .right: min(count - 1, current + 1)
        case .up: current - columnCount >= 0 ? current - columnCount : current
        case .down: current + columnCount < count ? current + columnCount : current
        }
        onNavigate(NavigationProposal(
            targetIndex: targetIndex,
            extendsRange: event.modifierFlags.contains(.shift)
        ))
        return true
    }

    private func direction(for event: NSEvent) -> Direction? {
        switch event.keyCode {
        case .leftArrow: return .left
        case .rightArrow: return .right
        case .downArrow: return .down
        case .upArrow: return .up
        default: break
        }
        // Use lowercased() so shift+vi-key also extends selection.
        switch event.charactersIgnoringModifiers?.lowercased() {
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
