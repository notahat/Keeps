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

    /// Receives the gap under the pointer as it moves, or nil when the
    /// pointer is not over a gap.
    var onGapHover: ((_ gapIndex: Int?) -> Void)?

    /// Empty slots to leave before the first item. Only the remainder by the
    /// column count is used, so a caller that removes items from the front
    /// of the list can pass the running total removed to keep the remaining
    /// items in their original columns.
    var leadingBlankSlots: Int = 0

    @ViewBuilder var cell: (_ item: PhotoItem, _ index: Int) -> Cell

    @State private var columnCount: Int = 1
    @State private var keyView: KeyAwareView.ResponderView?
    @State private var scrollPosition = ScrollPosition()
    @State private var scrollOffset: CGFloat = 0
    @State private var pinnedItem: PinnedItem?

    /// An item to hold in place on screen through the next change to the
    /// items, with the slot (blanks included) it had before that change.
    private struct PinnedItem {
        let id: UUID
        let slot: Int
    }

    /// The state whose changes may call for a scroll.
    private struct ScrollTrigger: Equatable {
        let itemIDs: [UUID]
        let selectedItemID: UUID?
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
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                scrollOffset = offset
            }
            // One handler for both kinds of change, because they conflict:
            // after a click the clicked item must stay exactly where it
            // was, so the selection isn't scrolled into view. Otherwise the
            // selection is followed, keyed on identity rather than index so
            // that reshaping items around an unchanged selection doesn't
            // scroll, and with a nil anchor so it scrolls only as far as
            // needed.
            .onChange(of: ScrollTrigger(itemIDs: items.map(\.id), selectedItemID: selectedItemID)) { _, trigger in
                if pinnedItem != nil {
                    restorePinnedItem()
                } else if let id = trigger.selectedItemID {
                    withAnimation { scrollProxy.scrollTo(id, anchor: nil) }
                }
            }
            .background {
                KeyAwareView(onKeyDown: { event in handleKeyEvent(event) }, onViewReady: { keyView = $0 })
            }
            .onAppear {
                if let selectedIndex {
                    scrollProxy.scrollTo(items[selectedIndex].id, anchor: .center)
                }
            }
        }
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
        }
        // Horizontally, each slot already carries half a gap.
        .padding(.vertical, Self.spacing)
        .padding(.horizontal, Self.spacing / 2)
    }

    /// After the items change in response to a click, scrolls so the
    /// clicked item is back at the same height on screen. Without this,
    /// removing cells above the viewport would carry the view forward.
    private func restorePinnedItem() {
        guard let pinnedItem else { return }
        self.pinnedItem = nil
        guard let newIndex = items.firstIndex(where: { $0.id == pinnedItem.id }) else { return }
        let offset = PhotoGridMetrics.scrollOffset(
            keepingItemFrom: pinnedItem.slot,
            to: newIndex + blankSlotCount,
            columnCount: columnCount,
            currentOffset: scrollOffset
        )
        scrollPosition.scrollTo(y: offset)
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
                guard let onGapHover else { return }
                switch phase {
                case let .active(location):
                    if case let .gap(gapIndex) = hitTarget(at: location, index: index) {
                        onGapHover(gapIndex)
                    } else {
                        onGapHover(nil)
                    }
                case .ended:
                    onGapHover(nil)
                }
            }
            .id(item.id)
    }

    /// Routes a single click to onGapTap or onTap, then takes keyboard focus.
    /// Pins the clicked item first, in case the caller reshapes the items.
    private func handleTap(at location: CGPoint, index: Int) {
        pinnedItem = PinnedItem(id: items[index].id, slot: index + blankSlotCount)
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
        // Changes from here on are keyboard-driven, so the selection
        // should be followed, not a click pinned.
        pinnedItem = nil
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

/// The grid's fixed geometry, exposed so cells can draw chrome that lines up
/// with the gaps between them. Columns are fixed-width, so gaps never
/// stretch with the window.
enum PhotoGridMetrics {
    static var cellSize: CGFloat {
        CGFloat(ThumbnailImage.displaySize)
    }

    /// The space between cells, horizontally and vertically.
    static let spacing: CGFloat = 12

    /// How many blank slots to show before the first item for a requested
    /// count: only the remainder by the column count, so at most a partial
    /// row. Pure.
    static func blankSlotCount(for requestedCount: Int, columnCount: Int) -> Int {
        max(0, requestedCount) % max(1, columnCount)
    }

    /// The distance from the top of the grid's content to the top of the
    /// row holding the item at `index`. Pure.
    static func rowTop(forIndex index: Int, columnCount: Int) -> CGFloat {
        let row = index / max(1, columnCount)
        return spacing + CGFloat(row) * (cellSize + spacing)
    }

    /// The scroll offset that keeps an item at the same height on screen
    /// after it moves from one index to another. Not clamped: the scroll
    /// view keeps out-of-range positions in bounds itself, and its minimum
    /// offset depends on content insets this doesn't know about. Pure.
    static func scrollOffset(
        keepingItemFrom oldIndex: Int, to newIndex: Int, columnCount: Int, currentOffset: CGFloat
    ) -> CGFloat {
        let shift = rowTop(forIndex: newIndex, columnCount: columnCount)
            - rowTop(forIndex: oldIndex, columnCount: columnCount)
        return currentOffset + shift
    }
}
