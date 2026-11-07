import Foundation

/// The cell the user's latest input points at: the clicked cell, or after a
/// key press, the first cell of the row in the middle of the view.
/// GridScrolling records one before acting on each click or key press, so
/// when the cells change it knows what to hold still and whether the change
/// came from a click.
nonisolated struct PinnedCell: Equatable {
    /// The cell's index among the cells as they were before the change.
    let index: Int
    let isFromClick: Bool
}

/// What the sort screen's grid should do about a change to its cells or
/// selection. Pure: GridScrolling works out the response here, then does
/// the scrolling.
///
/// When the cells change, as when groups collapse, the view holds still
/// around one cell, and the selection isn't chased, even if it moved too.
/// When only the selection changes, the view follows it, unless a click
/// moved it, since the clicked cell is already on screen.
nonisolated enum GridScrollResponse: Equatable {
    /// Keep the cell at this index among the old cells, or if it has gone,
    /// its nearest survivor, at the same height on screen.
    case holdCell(atOldIndex: Int)

    /// Scroll just far enough to show the selected photo's cell.
    case followSelection(UUID)

    /// Leave the view where it is.
    case stay

    /// Choose the response to a change from one set of cells to another.
    /// The cell held is the old cells' stable item if there is one,
    /// otherwise the pinned cell; with neither, the view stays where it is.
    static func choose(
        from old: GridScrolling.Cells,
        to new: GridScrolling.Cells,
        pinnedCell: PinnedCell?
    ) -> GridScrollResponse {
        if old.itemIDs != new.itemIDs {
            let stableIndex = old.stableItemID.flatMap { stableID in old.itemIDs.firstIndex(of: stableID) }
            guard let heldIndex = stableIndex ?? pinnedCell?.index else { return .stay }
            return .holdCell(atOldIndex: heldIndex)
        }
        if old.selectedItemID != new.selectedItemID,
           pinnedCell?.isFromClick != true,
           let selectedItemID = new.selectedItemID
        {
            return .followSelection(selectedItemID)
        }
        return .stay
    }
}
