import SwiftUI

/// The grid screen of the grouping workflow: a photo grid surface showing the
/// workflow's cells, with edge clicks toggling group boundaries and cell
/// clicks selecting photos or collapsed groups.
struct GroupCullGridScreen: View {
    var workflow: GroupCullWorkflow

    @State private var hoveredGap: Int?

    var body: some View {
        // Derived once per render rather than once per cell, since each
        // derivation walks the whole folder.
        let layout = workflow.layout
        let selectedCellIndex = workflow.selectedCellIndex
        PhotoGridSurface(
            items: workflow.displayedItems,
            selectedIndex: selectedCellIndex,
            onNavigate: { proposal in workflow.selectCell(at: proposal.targetIndex) },
            onKeyDown: { event in handleKeyEvent(event) },
            onTap: { index, _ in workflow.selectCell(at: index) },
            onDoubleTap: { _ in },
            onGapTap: { gapIndex in workflow.toggleBoundary(atGap: gapIndex) },
            onGapHover: { gapIndex in hoveredGap = gapIndex },
            // Collapsing removes cells ahead of the open photos; matching
            // blanks keep those photos in their original columns.
            leadingBlankSlots: layout.hiddenPhotoCount,
            // Where grouping has reached stays put when groups collapse.
            stableItemID: workflow.workingPointPhotoIndex.map { workflow.items[$0].id },
            // Only read on first layout, to restore a saved session.
            initialScrollAnchor: workflow.scrollAnchor,
            onScrollAnchorChange: { anchor in workflow.updateScrollAnchor(anchor) }
        ) { item, index in
            GroupCullCell(
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
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        if event.keyCode == .escape {
            workflow.clearSelection()
            return true
        }
        let hasModifiers = !event.modifierFlags.intersection([.command, .control, .option]).isEmpty
        if !hasModifiers, event.charactersIgnoringModifiers?.lowercased() == "c" {
            workflow.collapseClosedGroups()
            return true
        }
        return false
    }

    /// The photos in a cell's group if it is collapsed, or nil for a single
    /// photo.
    private func collapsedPhotos(ofCell cellIndex: Int, in layout: GroupLayout) -> ArraySlice<PhotoItem>? {
        let cell = layout.cells[cellIndex]
        return cell.isCollapsed ? workflow.items[cell.photoRange] : nil
    }

    /// How to draw the bar at a gap: nothing at a locked gap, placed if
    /// there is a boundary there, previewed if the pointer is over it.
    private func boundaryStyle(atGap gapIndex: Int, in layout: GroupLayout) -> GroupCullCell.BoundaryStyle? {
        guard layout.isGapEditable(gapIndex) else { return nil }
        if layout.hasBoundary(atGap: gapIndex) {
            return .placed
        }
        return gapIndex == hoveredGap ? .preview : nil
    }
}
