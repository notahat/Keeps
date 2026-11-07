import Foundation
@testable import Keeps
import Testing

struct PhotoGridMetricsTests {
    private let rowHeight = PhotoGridMetrics.cellSize + PhotoGridMetrics.spacing

    @Test("The first row starts below the top padding")
    func firstRowTop() {
        #expect(PhotoGridMetrics.rowTop(forSlot: 2, columnCount: 4) == PhotoGridMetrics.spacing)
    }

    @Test("Each later row starts one row height further down")
    func laterRowTop() {
        let top = PhotoGridMetrics.rowTop(forSlot: 9, columnCount: 4)

        #expect(top == PhotoGridMetrics.spacing + 2 * rowHeight)
    }

    @Test(
        "Only a partial row of blank slots is ever shown",
        arguments: [(hiddenCount: 3, blankCount: 3), (hiddenCount: 9, blankCount: 1), (hiddenCount: 8, blankCount: 0)]
    )
    func blankSlotsWrapAtColumnCount(hiddenCount: Int, blankCount: Int) {
        #expect(PhotoGridMetrics.blankSlotCount(for: hiddenCount, columnCount: 4) == blankCount)
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

    @Test("A pinned cell that survives a change is pinned itself")
    func survivingPinnedCell() throws {
        let ids = (0 ..< 6).map { _ in UUID() }
        let newIDs = [ids[0], ids[3], ids[4], ids[5]]

        let survivor = try #require(PhotoGridMetrics.survivingCell(from: 3, oldIDs: ids, newIDs: newIDs))

        #expect(survivor.oldIndex == 3)
        #expect(survivor.newIndex == 1)
    }

    @Test("When the pinned cell goes, the nearest earlier survivor takes its place")
    func earlierSurvivorPreferred() throws {
        let ids = (0 ..< 6).map { _ in UUID() }
        // Cells 1 to 3 have folded into cell 0, as when a group collapses.
        let newIDs = [ids[0], ids[4], ids[5]]

        let survivor = try #require(PhotoGridMetrics.survivingCell(from: 2, oldIDs: ids, newIDs: newIDs))

        #expect(survivor.oldIndex == 0)
        #expect(survivor.newIndex == 0)
    }

    @Test("When nothing earlier survives, the nearest later survivor is used")
    func laterSurvivorAsFallback() throws {
        let ids = (0 ..< 6).map { _ in UUID() }
        let newIDs = [ids[4], ids[5]]

        let survivor = try #require(PhotoGridMetrics.survivingCell(from: 2, oldIDs: ids, newIDs: newIDs))

        #expect(survivor.oldIndex == 4)
        #expect(survivor.newIndex == 0)
    }

    @Test("The photo after the last boundary stays put when the groups before it collapse")
    func workingPointHeldThroughCollapse() {
        // Twenty photos in four columns; groups 0..<6 and 6..<12 collapse
        // into piles shown by photos 0 and 6, hiding ten photos.
        let ids = (0 ..< 20).map { _ in UUID() }
        let newIDs = [ids[0], ids[6]] + ids[12...]

        let offset = PhotoGridMetrics.scrollOffsetHoldingCell(
            at: 12,
            from: PhotoGridMetrics.SlottedCells(photoIDs: ids, blankSlotCount: 0),
            to: PhotoGridMetrics.SlottedCells(
                photoIDs: Array(newIDs),
                blankSlotCount: PhotoGridMetrics.blankSlotCount(for: 10, columnCount: 4)
            ),
            columnCount: 4,
            currentOffset: 1000
        )

        // Photo 12 moves from slot 12 (row 3) to slot 4 (row 1).
        #expect(offset == 1000 - 2 * rowHeight)
    }

    @Test("Holding a cell that has gone falls back to its nearest survivor")
    func holdingFallsBackToSurvivor() {
        let ids = (0 ..< 8).map { _ in UUID() }
        let newIDs = [ids[0]] + ids[4...]

        let offset = PhotoGridMetrics.scrollOffsetHoldingCell(
            at: 2,
            from: PhotoGridMetrics.SlottedCells(photoIDs: ids, blankSlotCount: 0),
            to: PhotoGridMetrics.SlottedCells(photoIDs: Array(newIDs), blankSlotCount: 3),
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

    @Test("A cell that moves up two rows keeps its place on screen when the scroll moves up two rows")
    func offsetFollowsCellUp() {
        let offset = PhotoGridMetrics.scrollOffset(
            keepingSlotContentsFrom: 20, to: 12, columnCount: 4, currentOffset: 1000
        )

        #expect(offset == 1000 - 2 * rowHeight)
    }

    @Test("A cell that stays in its row needs no scroll change")
    func offsetUnchangedWithinRow() {
        let offset = PhotoGridMetrics.scrollOffset(
            keepingSlotContentsFrom: 21, to: 20, columnCount: 4, currentOffset: 1000
        )

        #expect(offset == 1000)
    }

    @Test(
        "Left and right step to the previous and next cell",
        arguments: [(direction: MoveDirection.left, to: 4), (direction: .right, to: 6)]
    )
    func leftAndRight(direction: MoveDirection, to: Int) {
        let target = PhotoGridMetrics.targetCell(from: 5, moving: direction, cellCount: 10, columnCount: 4)

        #expect(target == to)
    }

    @Test(
        "Left and right stop at the first and last cells",
        arguments: [(from: 0, direction: MoveDirection.left), (from: 9, direction: .right)]
    )
    func leftAndRightStopAtEnds(from: Int, direction: MoveDirection) {
        let target = PhotoGridMetrics.targetCell(from: from, moving: direction, cellCount: 10, columnCount: 4)

        #expect(target == from)
    }

    @Test(
        "Up and down move a whole row",
        arguments: [(direction: MoveDirection.up, to: 1), (direction: .down, to: 9)]
    )
    func upAndDown(direction: MoveDirection, to: Int) {
        let target = PhotoGridMetrics.targetCell(from: 5, moving: direction, cellCount: 10, columnCount: 4)

        #expect(target == to)
    }

    @Test(
        "Up and down stay put when there's no cell in that direction",
        arguments: [(from: 2, direction: MoveDirection.up), (from: 7, direction: .down)]
    )
    func noCellAboveOrBelow(from: Int, direction: MoveDirection) {
        let target = PhotoGridMetrics.targetCell(from: from, moving: direction, cellCount: 10, columnCount: 4)

        #expect(target == from)
    }
}
