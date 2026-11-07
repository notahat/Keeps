import Foundation

/// The sort grid's geometry. Each cell sits in a slot: the cell plus half
/// the gap on either side (see slotWidth). Columns are fixed-width, so gaps
/// never stretch with the window.
///
/// Holds the fixed sizes, which cells use to draw boundary bars that line
/// up with the gaps, and pure functions over them for rows, slots, scroll
/// offsets, and where the movement keys go.
enum PhotoGridMetrics {
    /// Where the grid's cells sit: the photo each cell shows, in order, after
    /// some blank slots.
    nonisolated struct SlottedCells {
        let itemIDs: [UUID]

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

    /// The item to hold in place after the items change, given the index of
    /// the item that was pinned: that item if it's still there, otherwise
    /// the nearest earlier one that is (when items fold into an earlier
    /// one, that's where they went), otherwise the nearest later one.
    /// Returns its old and new indices, or nil if nothing survives. Pure.
    static func survivingItem(
        from pinnedIndex: Int, oldIDs: [UUID], newIDs: [UUID]
    ) -> (oldIndex: Int, newIndex: Int)? {
        guard oldIDs.indices.contains(pinnedIndex) else { return nil }
        let newIndexByID = Dictionary(uniqueKeysWithValues: newIDs.enumerated().map { ($1, $0) })
        let searchOrder = Array((0 ... pinnedIndex).reversed()) + Array(pinnedIndex + 1 ..< oldIDs.count)
        for oldIndex in searchOrder {
            if let newIndex = newIndexByID[oldIDs[oldIndex]] {
                return (oldIndex, newIndex)
            }
        }
        return nil
    }

    /// The scroll offset that keeps the item at `pinnedIndex` among the old
    /// cells (or, if it has gone, its nearest survivor) at the same height on
    /// screen across a change from the old cells to the new. Nil if nothing
    /// survives. Pure.
    static func scrollOffsetHoldingItem(
        at pinnedIndex: Int,
        from old: SlottedCells,
        to new: SlottedCells,
        columnCount: Int,
        currentOffset: CGFloat
    ) -> CGFloat? {
        guard let survivor = survivingItem(from: pinnedIndex, oldIDs: old.itemIDs, newIDs: new.itemIDs)
        else { return nil }
        return scrollOffset(
            keepingItemFrom: survivor.oldIndex + old.blankSlotCount,
            to: survivor.newIndex + new.blankSlotCount,
            columnCount: columnCount,
            currentOffset: currentOffset
        )
    }

    /// The scroll offset that puts the view a given distance into the row
    /// holding a slot, as when restoring a saved scroll anchor. Pure.
    static func offset(forSlot slot: Int, offsetFromRowTop: CGFloat, columnCount: Int) -> CGFloat {
        rowTop(forIndex: slot, columnCount: columnCount) + offsetFromRowTop
    }

    /// The first slot of the row at a height within the grid's content.
    /// Pure.
    static func firstSlot(inRowAt height: CGFloat, columnCount: Int) -> Int {
        let row = max(0, Int(((height - spacing) / (cellSize + spacing)).rounded(.down)))
        return row * max(1, columnCount)
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
