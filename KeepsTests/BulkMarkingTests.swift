import Foundation
@testable import Keeps
import Testing

struct BulkMarkingTests {
    @Test func bulkMarkMarksAllItemsInRange() throws {
        let library = makeLibrary(photoCount: 5)

        library.selectItem(at: 1)
        library.extendSelection(to: 3)
        library.applyMarkAndAdvance(.pick)

        #expect(library.mark(for: library.items[1].id) == .pick)
        #expect(library.mark(for: library.items[2].id) == .pick)
        #expect(library.mark(for: library.items[3].id) == .pick)
    }

    @Test func bulkMarkDoesNotMarkItemsOutsideRange() throws {
        let library = makeLibrary(photoCount: 5)

        library.selectItem(at: 1)
        library.extendSelection(to: 3)
        library.applyMarkAndAdvance(.pick)

        #expect(library.mark(for: library.items[0].id) == nil)
        #expect(library.mark(for: library.items[4].id) == nil)
    }

    @Test func bulkMarkDoesNotAdvanceSelection() throws {
        let library = makeLibrary(photoCount: 5)

        library.selectItem(at: 1)
        library.extendSelection(to: 3)
        library.applyMarkAndAdvance(.pick)

        #expect(library.selectedIndex == 3)
    }

    @Test func bulkMarkPreservesRange() throws {
        let library = makeLibrary(photoCount: 5)

        library.selectItem(at: 1)
        library.extendSelection(to: 3)
        library.applyMarkAndAdvance(.pick)

        #expect(library.selectionRange == 1 ... 3)
    }

    @Test func bulkMarkSetsLastMarkEvent() throws {
        let library = makeLibrary(photoCount: 5)

        library.selectItem(at: 1)
        library.extendSelection(to: 3)
        library.applyMarkAndAdvance(.reject)

        #expect(library.lastMarkEvent?.mark == .reject)
    }

    @Test func singleSelectionStillMarksAndAdvances() throws {
        let library = makeLibrary(photoCount: 5)

        library.selectItem(at: 1)
        library.applyMarkAndAdvance(.pick)

        #expect(library.mark(for: library.items[1].id) == .pick)
        #expect(library.selectedIndex == 2)
    }
}
