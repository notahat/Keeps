import Foundation
@testable import Keeps
import Testing

struct BulkMarkingTests {
    @Test func bulkMarkMarksAllItemsInRange() throws {
        let workflow = makeWorkflow(photoCount: 5)

        workflow.selectItem(at: 1)
        workflow.extendSelection(to: 3)
        workflow.applyMarkAndAdvance(.pick)

        #expect(workflow.mark(for: workflow.items[1].id) == .pick)
        #expect(workflow.mark(for: workflow.items[2].id) == .pick)
        #expect(workflow.mark(for: workflow.items[3].id) == .pick)
    }

    @Test func bulkMarkDoesNotMarkItemsOutsideRange() throws {
        let workflow = makeWorkflow(photoCount: 5)

        workflow.selectItem(at: 1)
        workflow.extendSelection(to: 3)
        workflow.applyMarkAndAdvance(.pick)

        #expect(workflow.mark(for: workflow.items[0].id) == nil)
        #expect(workflow.mark(for: workflow.items[4].id) == nil)
    }

    @Test func bulkMarkDoesNotAdvanceSelection() throws {
        let workflow = makeWorkflow(photoCount: 5)

        workflow.selectItem(at: 1)
        workflow.extendSelection(to: 3)
        workflow.applyMarkAndAdvance(.pick)

        #expect(workflow.selectedIndex == 3)
    }

    @Test func bulkMarkPreservesRange() throws {
        let workflow = makeWorkflow(photoCount: 5)

        workflow.selectItem(at: 1)
        workflow.extendSelection(to: 3)
        workflow.applyMarkAndAdvance(.pick)

        #expect(workflow.selectionRange == 1 ... 3)
    }

    @Test func bulkMarkSetsLastMarkEvent() throws {
        let workflow = makeWorkflow(photoCount: 5)

        workflow.selectItem(at: 1)
        workflow.extendSelection(to: 3)
        workflow.applyMarkAndAdvance(.reject)

        #expect(workflow.lastMarkEvent?.mark == .reject)
    }

    @Test func singleSelectionStillMarksAndAdvances() throws {
        let workflow = makeWorkflow(photoCount: 5)

        workflow.selectItem(at: 1)
        workflow.applyMarkAndAdvance(.pick)

        #expect(workflow.mark(for: workflow.items[1].id) == .pick)
        #expect(workflow.selectedIndex == 2)
    }
}
