import Foundation
@testable import Keeps
import Testing

struct PhotoGridMetricsTests {
    private let rowHeight = PhotoGridMetrics.cellSize + PhotoGridMetrics.spacing

    @Test("The first row starts below the top padding")
    func firstRowTop() {
        #expect(PhotoGridMetrics.rowTop(forIndex: 2, columnCount: 4) == PhotoGridMetrics.spacing)
    }

    @Test("Each later row starts one row height further down")
    func laterRowTop() {
        let top = PhotoGridMetrics.rowTop(forIndex: 9, columnCount: 4)

        #expect(top == PhotoGridMetrics.spacing + 2 * rowHeight)
    }

    @Test("Only a partial row of blank slots is ever shown")
    func blankSlotsWrapAtColumnCount() {
        #expect(PhotoGridMetrics.blankSlotCount(for: 3, columnCount: 4) == 3)
        #expect(PhotoGridMetrics.blankSlotCount(for: 9, columnCount: 4) == 1)
        #expect(PhotoGridMetrics.blankSlotCount(for: 8, columnCount: 4) == 0)
    }

    @Test("The slot at a height is the first slot of the row there")
    func slotAtHeight() {
        let height = PhotoGridMetrics.spacing + 2 * rowHeight + 50

        #expect(PhotoGridMetrics.firstSlot(inRowAt: height, columnCount: 4) == 8)
    }

    @Test("Heights above the first row give the first slot")
    func slotAboveFirstRow() {
        #expect(PhotoGridMetrics.firstSlot(inRowAt: -100, columnCount: 4) == 0)
    }

    @Test("A pinned item that survives a change is pinned itself")
    func survivingPinnedItem() {
        let ids = (0 ..< 6).map { _ in UUID() }
        let newIDs = [ids[0], ids[3], ids[4], ids[5]]

        let survivor = PhotoGridMetrics.survivingItem(from: 3, oldIDs: ids, newIDs: newIDs)

        #expect(survivor?.oldIndex == 3)
        #expect(survivor?.newIndex == 1)
    }

    @Test("When the pinned item goes, the nearest earlier survivor takes its place")
    func earlierSurvivorPreferred() {
        let ids = (0 ..< 6).map { _ in UUID() }
        // Items 1 to 3 have folded into item 0, as when a group collapses.
        let newIDs = [ids[0], ids[4], ids[5]]

        let survivor = PhotoGridMetrics.survivingItem(from: 2, oldIDs: ids, newIDs: newIDs)

        #expect(survivor?.oldIndex == 0)
        #expect(survivor?.newIndex == 0)
    }

    @Test("When nothing earlier survives, the nearest later survivor is used")
    func laterSurvivorAsFallback() {
        let ids = (0 ..< 6).map { _ in UUID() }
        let newIDs = [ids[4], ids[5]]

        let survivor = PhotoGridMetrics.survivingItem(from: 2, oldIDs: ids, newIDs: newIDs)

        #expect(survivor?.oldIndex == 4)
        #expect(survivor?.newIndex == 0)
    }

    @Test("The photo after the last boundary stays put when the groups before it collapse")
    func workingPointHeldThroughCollapse() {
        // Twenty photos in four columns; groups 0..<6 and 6..<12 collapse
        // into piles shown by photos 0 and 6, hiding ten photos.
        let ids = (0 ..< 20).map { _ in UUID() }
        let newIDs = [ids[0], ids[6]] + ids[12...]

        let offset = PhotoGridMetrics.scrollOffsetHoldingItem(
            at: 12,
            from: PhotoGridMetrics.SlottedCells(itemIDs: ids, blankSlotCount: 0),
            to: PhotoGridMetrics.SlottedCells(
                itemIDs: Array(newIDs),
                blankSlotCount: PhotoGridMetrics.blankSlotCount(for: 10, columnCount: 4)
            ),
            columnCount: 4,
            currentOffset: 1000
        )

        // Photo 12 moves from slot 12 (row 3) to slot 4 (row 1).
        #expect(offset == 1000 - 2 * rowHeight)
    }

    @Test("Holding an item that has gone falls back to its nearest survivor")
    func holdingFallsBackToSurvivor() {
        let ids = (0 ..< 8).map { _ in UUID() }
        let newIDs = [ids[0]] + ids[4...]

        let offset = PhotoGridMetrics.scrollOffsetHoldingItem(
            at: 2,
            from: PhotoGridMetrics.SlottedCells(itemIDs: ids, blankSlotCount: 0),
            to: PhotoGridMetrics.SlottedCells(itemIDs: Array(newIDs), blankSlotCount: 3),
            columnCount: 4,
            currentOffset: 1000
        )

        // Photo 0 survives and stays in slot 0, so nothing moves.
        #expect(offset == 1000)
    }

    @Test("The offset for a slot is the top of its row plus the distance into that row")
    func offsetForSlot() {
        let offset = PhotoGridMetrics.offset(forSlot: 13, offsetFromRowTop: 40, columnCount: 4)

        #expect(offset == PhotoGridMetrics.spacing + 3 * rowHeight + 40)
    }

    @Test("An item that moves up two rows keeps its place on screen when the scroll moves up two rows")
    func offsetFollowsItemUp() {
        let offset = PhotoGridMetrics.scrollOffset(
            keepingItemFrom: 20, to: 12, columnCount: 4, currentOffset: 1000
        )

        #expect(offset == 1000 - 2 * rowHeight)
    }

    @Test("An item that stays in its row needs no scroll change")
    func offsetUnchangedWithinRow() {
        let offset = PhotoGridMetrics.scrollOffset(
            keepingItemFrom: 21, to: 20, columnCount: 4, currentOffset: 1000
        )

        #expect(offset == 1000)
    }
}

struct PhotoGridMetricsMovementTests {
    @Test("Left and right step through the cells, stopping at either end")
    func leftAndRight() {
        let targets = [
            PhotoGridMetrics.targetCell(from: 5, moving: .left, cellCount: 10, columnCount: 4),
            PhotoGridMetrics.targetCell(from: 5, moving: .right, cellCount: 10, columnCount: 4),
            PhotoGridMetrics.targetCell(from: 0, moving: .left, cellCount: 10, columnCount: 4),
            PhotoGridMetrics.targetCell(from: 9, moving: .right, cellCount: 10, columnCount: 4),
        ]

        #expect(targets == [4, 6, 0, 9])
    }

    @Test("Up and down move a whole row")
    func upAndDown() {
        let up = PhotoGridMetrics.targetCell(from: 5, moving: .up, cellCount: 10, columnCount: 4)
        let down = PhotoGridMetrics.targetCell(from: 5, moving: .down, cellCount: 10, columnCount: 4)

        #expect(up == 1)
        #expect(down == 9)
    }

    @Test("Up and down stay put when there's no cell in that direction")
    func noCellAboveOrBelow() {
        let up = PhotoGridMetrics.targetCell(from: 2, moving: .up, cellCount: 10, columnCount: 4)
        let down = PhotoGridMetrics.targetCell(from: 7, moving: .down, cellCount: 10, columnCount: 4)

        #expect(up == 2)
        #expect(down == 7)
    }
}
