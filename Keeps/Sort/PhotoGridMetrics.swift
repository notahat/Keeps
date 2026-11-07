import Foundation

/// The sort grid's geometry. Each cell sits in a slot: the cell plus half
/// the gap on either side (see slotWidth). Columns are fixed-width, so gaps
/// never stretch with the window.
///
/// Holds the fixed sizes, which cells use to draw boundary bars that line
/// up with the gaps, and pure functions over them for rows, slots, scroll
/// offsets, and where the movement keys go. Every column count passed in
/// must be at least 1, as SortScreen ensures when it measures the grid.
enum PhotoGridMetrics {
    /// Where the grid's cells sit: the photo each cell shows, in order, after
    /// some blank slots.
    nonisolated struct SlottedCells {
        let photoIDs: [UUID]

        /// The blank slots shown before the first cell (see blankSlotCount).
        let blankSlotCount: Int
    }

    /// The width and height of a cell, a framed photo's standard frame.
    static var cellSize: CGFloat {
        CGFloat(FramedPhoto.standardFrameLength)
    }

    /// The space between cells, horizontally and vertically.
    static let spacing = FramedPhoto.gridSpacing

    /// The width each cell occupies: the cell plus half the gap on either
    /// side. Cells own their share of the gap so that clicks and hovers
    /// there land on a cell instead of falling through, so the grid itself
    /// has no horizontal spacing.
    static var slotWidth: CGFloat {
        cellSize + spacing
    }

    /// The cell a movement key goes to from the given cell. Left and right
    /// step through the cells in order; up and down move a whole row. Stays
    /// put when there's no cell in that direction. Pure.
    static func targetCell(from index: Int, moving direction: MoveDirection, cellCount: Int, columnCount: Int) -> Int {
        switch direction {
        case .left: max(0, index - 1)
        case .right: min(cellCount - 1, index + 1)
        case .up: index - columnCount >= 0 ? index - columnCount : index
        case .down: index + columnCount < cellCount ? index + columnCount : index
        }
    }

    /// How many blank slots to show before the first cell for a requested
    /// count: only the remainder by the column count, so at most a partial
    /// row. Pure.
    static func blankSlotCount(for requestedCount: Int, columnCount: Int) -> Int {
        requestedCount % columnCount
    }

    /// The distance from the top of the grid's content to the top of the
    /// row holding a slot. Pure.
    static func rowTop(forSlot slot: Int, columnCount: Int) -> CGFloat {
        let row = slot / columnCount
        return spacing + CGFloat(row) * (cellSize + spacing)
    }

    /// The cell to hold in place after the cells change, given the index of
    /// the cell that was pinned: that cell if it's still there, otherwise
    /// the nearest earlier one that is (when cells fold into an earlier
    /// one, that's where they went), otherwise the nearest later one.
    /// Returns its old and new indices, or nil if nothing survives. Pure.
    static func survivingCell(
        from pinnedIndex: Int, oldIDs: [UUID], newIDs: [UUID]
    ) -> (oldIndex: Int, newIndex: Int)? {
        guard oldIDs.indices.contains(pinnedIndex) else { return nil }
        let newIndexByID = Dictionary(uniqueKeysWithValues: newIDs.enumerated().map { index, id in (id, index) })
        let searchOrder = Array((0 ... pinnedIndex).reversed()) + Array(pinnedIndex + 1 ..< oldIDs.count)
        for oldIndex in searchOrder {
            if let newIndex = newIndexByID[oldIDs[oldIndex]] {
                return (oldIndex, newIndex)
            }
        }
        return nil
    }

    /// The scroll offset that keeps the cell at `pinnedIndex` among the old
    /// cells (or, if it has gone, its nearest survivor) at the same height on
    /// screen across a change from the old cells to the new. Nil if nothing
    /// survives. Pure.
    static func scrollOffsetHoldingCell(
        at pinnedIndex: Int,
        from old: SlottedCells,
        to new: SlottedCells,
        columnCount: Int,
        currentOffset: CGFloat
    ) -> CGFloat? {
        guard let survivor = survivingCell(from: pinnedIndex, oldIDs: old.photoIDs, newIDs: new.photoIDs)
        else { return nil }
        return scrollOffset(
            keepingSlotContentsFrom: survivor.oldIndex + old.blankSlotCount,
            to: survivor.newIndex + new.blankSlotCount,
            columnCount: columnCount,
            currentOffset: currentOffset
        )
    }

    /// The scroll offset that puts the view a given distance into the row
    /// holding a slot, as when restoring a saved scroll anchor. Pure.
    static func offset(forSlot slot: Int, offsetFromRowTop: CGFloat, columnCount: Int) -> CGFloat {
        rowTop(forSlot: slot, columnCount: columnCount) + offsetFromRowTop
    }

    /// The first slot of the row at a height within the grid's content.
    /// Pure.
    static func firstSlot(inRowAt height: CGFloat, columnCount: Int) -> Int {
        let row = max(0, Int(((height - spacing) / (cellSize + spacing)).rounded(.down)))
        return row * columnCount
    }

    /// The scroll offset that keeps a cell at the same height on screen
    /// after it moves from one slot to another. Not clamped: the scroll
    /// view keeps out-of-range positions in bounds itself, and its minimum
    /// offset depends on content insets this doesn't know about. Pure.
    static func scrollOffset(
        keepingSlotContentsFrom oldSlot: Int, to newSlot: Int, columnCount: Int, currentOffset: CGFloat
    ) -> CGFloat {
        let shift = rowTop(forSlot: newSlot, columnCount: columnCount)
            - rowTop(forSlot: oldSlot, columnCount: columnCount)
        return currentOffset + shift
    }
}
