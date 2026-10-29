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
