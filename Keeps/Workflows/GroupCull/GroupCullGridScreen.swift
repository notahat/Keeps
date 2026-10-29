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
            leadingBlankSlots: layout.hiddenPhotoCount
        ) { item, index in
            GroupCullCell(
                item: item,
                isSelected: index == selectedCellIndex,
                leadingBoundary: boundaryStyle(atGap: index, in: layout),
                trailingBoundary: boundaryStyle(atGap: index + 1, in: layout)
            )
        }
    }

    /// Handles non-navigation keys: Escape clears the selection.
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard event.keyCode == .escape else { return false }
        workflow.clearSelection()
        return true
    }

    /// How to draw the bar at a gap: placed if there is a boundary there,
    /// previewed if the pointer is over it, otherwise not at all.
    private func boundaryStyle(atGap gapIndex: Int, in layout: GroupLayout) -> GroupCullCell.BoundaryStyle? {
        if layout.hasBoundary(atGap: gapIndex) {
            return .placed
        }
        return gapIndex == hoveredGap ? .preview : nil
    }
}
