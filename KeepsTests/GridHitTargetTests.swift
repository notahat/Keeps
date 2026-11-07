import Foundation
@testable import Keeps
import Testing

struct GridHitTargetTests {
    @Test("A click in the middle of a cell targets the cell")
    func middleClickTargetsCell() {
        let target = GridHitTarget.resolve(offset: 130, cellWidth: 260, index: 3)

        #expect(target == .cell(3))
    }

    @Test("A click near the left edge targets the gap before the cell")
    func leftEdgeTargetsGapBefore() {
        let target = GridHitTarget.resolve(offset: 10, cellWidth: 260, index: 3)

        #expect(target == .gap(beforeIndex: 3))
    }

    @Test("A click near the right edge targets the gap after the cell")
    func rightEdgeTargetsGapAfter() {
        let target = GridHitTarget.resolve(offset: 250, cellWidth: 260, index: 3)

        #expect(target == .gap(beforeIndex: 4))
    }

    @Test("The right edge of one cell and the left edge of the next share a gap")
    func adjacentEdgesShareGap() {
        let rightOfFirst = GridHitTarget.resolve(offset: 250, cellWidth: 260, index: 4)
        let leftOfSecond = GridHitTarget.resolve(offset: 10, cellWidth: 260, index: 5)

        #expect(rightOfFirst == leftOfSecond)
    }

    @Test("The left edge of the first cell targets the cell, since there is no gap before it")
    func firstCellLeftEdgeTargetsCell() {
        let target = GridHitTarget.resolve(offset: 10, cellWidth: 260, index: 0)

        #expect(target == .cell(0))
    }

    @Test("A click just inside the edge zone boundary targets the cell")
    func justInsideEdgeZoneTargetsCell() {
        let target = GridHitTarget.resolve(offset: 53, cellWidth: 260, index: 3)

        #expect(target == .cell(3))
    }

    @Test("A gap target gives its gap index")
    func gapTargetGivesGapIndex() {
        #expect(GridHitTarget.gap(beforeIndex: 4).gapIndex == 4)
    }

    @Test("A cell target gives no gap index")
    func cellTargetGivesNoGapIndex() {
        #expect(GridHitTarget.cell(4).gapIndex == nil)
    }
}
