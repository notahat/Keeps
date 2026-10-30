import SwiftUI

/// The sort screen, where the folder is split into groups: a photo grid
/// surface showing the grouping's cells, with edge clicks toggling group
/// boundaries and cell clicks selecting photos or collapsed groups.
struct SortScreen: View {
    @Bindable var grouping: Grouping

    @State private var hoveredGap: Int?

    var body: some View {
        // Found once per render rather than once per cell, since finding
        // the selected cell searches the whole layout.
        let layout = grouping.layout
        let selectedCellIndex = grouping.selectedCellIndex
        PhotoGridSurface(
            items: grouping.displayedItems,
            selectedIndex: selectedCellIndex,
            onNavigate: { proposal in grouping.selectCell(at: proposal.targetIndex) },
            onKeyDown: { press in handleKeyPress(press) },
            onTap: { index in grouping.selectCell(at: index) },
            onDoubleTap: { _ in },
            onGapTap: { gapIndex in grouping.toggleBoundary(atGap: gapIndex) },
            hoveredGap: $hoveredGap,
            // Collapsing removes cells ahead of the open photos; matching
            // blanks keep those photos in their original columns.
            leadingBlankSlots: layout.hiddenPhotoCount,
            // Where grouping has reached stays put when groups collapse.
            stableItemID: grouping.workingPointPhotoIndex.map { grouping.items[$0].id },
            scrollAnchor: $grouping.scrollAnchor
        ) { item, index in
            SortCell(
                item: item,
                isSelected: index == selectedCellIndex,
                leadingBoundary: boundaryStyle(atGap: index, in: layout),
                trailingBoundary: boundaryStyle(atGap: index + 1, in: layout),
                collapsedPhotos: collapsedPhotos(ofCell: index, in: layout)
            )
        }
    }

    /// Handles non-navigation keys: Escape clears the selection, and C
    /// collapses every group closed so far.
    private func handleKeyPress(_ press: KeyPress) -> Bool {
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
}
