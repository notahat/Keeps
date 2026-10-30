import AppKit
import SwiftUI

/// The sort screen, where the folder is split into groups: a lazy scrolling
/// grid with one cell per photo or collapsed group. Clicking the edge of a
/// cell toggles the boundary in that gap, and clicking its middle selects it.
/// Arrow and h/j/k/l keys move the selection, Escape clears it, and C
/// collapses every group closed so far.
///
/// Draws the cells, handles input, and owns the grid geometry (column math)
/// and keyboard focus. Scrolling is left to GridScrolling, and the grouping
/// itself lives in Grouping.
struct SortScreen: View {
    @Bindable var grouping: Grouping

    /// The gap under the pointer, or nil when the pointer is not over a gap.
    @State private var hoveredGap: Int?

    @State private var scrolling = GridScrolling()
    @FocusState private var isFocused: Bool

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

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: Self.slotWidth, maximum: Self.slotWidth), spacing: 0)]
    }

    /// The cells as scrolling sees them. Collapsing removes cells ahead of
    /// the open photos; blank slots for the hidden photos keep those photos
    /// in their original columns. Where grouping has reached stays put when
    /// groups collapse.
    private var scrollCells: GridScrolling.Cells {
        GridScrolling.Cells(
            itemIDs: grouping.cellItems.map(\.id),
            selectedItemID: grouping.selectedCellIndex.map { grouping.cellItems[$0].id },
            stableItemID: grouping.workingPointPhotoIndex.map { grouping.items[$0].id },
            leadingBlankSlots: grouping.layout.hiddenPhotoCount
        )
    }

    var body: some View {
        let scrollCells = scrollCells
        ScrollViewReader { scrollProxy in
            ScrollView {
                grid(blankSlotCount: scrolling.blankSlotCount(for: scrollCells))
            }
            .gridScrolling(
                scrolling,
                cells: scrollCells,
                scrollAnchor: $grouping.scrollAnchor,
                scrollProxy: scrollProxy
            )
            .focusable()
            .focusEffectDisabled()
            .focused($isFocused)
            .onKeyPress { press in
                handleKeyPress(press) ? .handled : .ignored
            }
            .onAppear {
                isFocused = true
            }
        }
    }

    /// The lazy grid of cells, measuring its own width for the column count.
    private func grid(blankSlotCount: Int) -> some View {
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
            scrolling.measure(columnCount: max(1, Int(width / Self.slotWidth)), cells: scrollCells)
        }
        // Horizontally, each slot already carries half a gap.
        .padding(.vertical, Self.spacing)
        .padding(.horizontal, Self.spacing / 2)
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
    /// takes keyboard focus.
    private func handleTap(at location: CGPoint, index: Int) {
        scrolling.noteClick(onCellAt: index)
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
        scrolling.noteKeyPress(cells: scrollCells)
        let cellCount = grouping.layout.cells.count
        let columnCount = scrolling.columnCount
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
