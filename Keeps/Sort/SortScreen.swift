import AppKit
import SwiftUI

/// The sort screen, where the folder is split into groups: a lazy scrolling
/// grid with one cell per photo or collapsed group. Clicking the edge of a
/// cell toggles the boundary in that gap, and clicking its middle selects it.
/// Arrow and h/j/k/l keys move the selection, Escape clears it, and C
/// collapses every group closed so far. Double-clicking a closed group, or
/// pressing Return with it selected, opens it on the pick screen. Done groups
/// leave the grid.
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

    private static let cellSize = PhotoGridMetrics.cellSize
    private static let spacing = PhotoGridMetrics.spacing
    private static let slotWidth = PhotoGridMetrics.slotWidth

    /// Fixed-width columns, as many as fit. The grid has no horizontal
    /// spacing, since each slot carries its share of the gap (see
    /// PhotoGridMetrics.slotWidth).
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
            .handlesKeys(isFocused: $isFocused, perform: handleKeyPress)
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
            pile: pile(ofCell: index, in: layout)
        )
        .padding(.horizontal, Self.spacing / 2)
        .contentShape(Rectangle())
        // The single click is simultaneous rather than a second tap
        // gesture, which would wait out the double-click time and make
        // selection lag.
        .onTapGesture(count: 2, coordinateSpace: .local) { location in
            handleDoubleClick(at: location, index: index)
        }
        .simultaneousGesture(SpatialTapGesture(coordinateSpace: .local).onEnded { value in
            handleTap(at: value.location, index: index)
        })
        .onContinuousHover { phase in
            updateHoveredGap(for: phase, index: index)
        }
        .id(item.id)
    }

    /// The pile a cell draws if it is a collapsed group, or nil for a single
    /// photo.
    private func pile(ofCell cellIndex: Int, in layout: GroupLayout) -> Pile? {
        let cell = layout.cells[cellIndex]
        guard cell.isCollapsed else { return nil }
        return Pile(group: cell.photoRange, items: grouping.items, keepers: grouping.keepers)
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
    /// takes keyboard focus. A locked gap, such as beside a collapsed group,
    /// counts as the cell.
    private func handleTap(at location: CGPoint, index: Int) {
        scrolling.noteClick(onCellAt: index)
        if let gapIndex = editableGap(at: location, index: index) {
            grouping.toggleBoundary(atGap: gapIndex)
        } else {
            grouping.selectCell(at: index)
        }
        isFocused = true
    }

    /// Opens the group of a double-clicked cell. Double-clicking an editable
    /// gap opens nothing, since its two clicks have already toggled the
    /// boundary and back.
    private func handleDoubleClick(at location: CGPoint, index: Int) {
        guard editableGap(at: location, index: index) == nil else { return }
        grouping.open(groupAtCell: index)
    }

    /// The gap a point within the slot at `index` targets, if it's one whose
    /// boundary can be toggled; nil for the cell itself or a locked gap.
    private func editableGap(at location: CGPoint, index: Int) -> Int? {
        guard let gapIndex = hitTarget(at: location, index: index).gapIndex,
              grouping.layout.isGapEditable(gapIndex)
        else { return nil }
        return gapIndex
    }

    /// What a point within the slot at `index` targets: the cell, or the gap
    /// at one of its edges.
    private func hitTarget(at location: CGPoint, index: Int) -> GridHitTarget {
        GridHitTarget.resolve(offset: location.x, cellWidth: Self.slotWidth, index: index)
    }

    /// Moves the selection for spatial keys using the current column count,
    /// and handles the other keys the screen knows.
    private func handleKeyPress(_ press: KeyPress) -> Bool {
        scrolling.noteKeyPress(cells: scrollCells)
        guard let direction = MoveDirection(press),
              let current = grouping.selectedCellIndex
        else { return handleCommandKey(press) }
        grouping.selectCell(at: PhotoGridMetrics.targetCell(
            from: current,
            moving: direction,
            cellCount: grouping.layout.cells.count,
            columnCount: scrolling.columnCount
        ))
        return true
    }

    /// Handles keys that aren't for moving the selection: Escape clears the
    /// selection, Return opens the selected cell's group, and C collapses
    /// every group closed so far. Returns false for any other key.
    private func handleCommandKey(_ press: KeyPress) -> Bool {
        if press.key == .escape {
            grouping.clearSelection()
            return true
        }
        if press.key == .return, let selectedCellIndex = grouping.selectedCellIndex {
            grouping.open(groupAtCell: selectedCellIndex)
            return true
        }
        if press.isPlain(letter: "c") {
            grouping.collapseClosedGroups()
            return true
        }
        return false
    }
}
