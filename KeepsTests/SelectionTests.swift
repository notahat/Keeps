import Foundation
@testable import Keeps
import Testing

struct SelectionTests {
    @Test func selectItemSetsSelectionAndCollapsesPreviousRange() {
        let workflow = makeWorkflow(photoCount: 5)

        workflow.selectItem(at: 2)

        #expect(workflow.selectedIndex == 2)
        #expect(workflow.selectionRange == 2 ... 2)
    }

    @Test func extendSelectionForwardFromAnchor() {
        let workflow = makeWorkflow(photoCount: 5)

        workflow.selectItem(at: 1)
        workflow.extendSelection(to: 3)

        #expect(workflow.selectedIndex == 3)
        #expect(workflow.selectionRange == 1 ... 3)
    }

    @Test func extendSelectionBackwardFromAnchor() {
        let workflow = makeWorkflow(photoCount: 5)

        workflow.selectItem(at: 3)
        workflow.extendSelection(to: 1)

        #expect(workflow.selectedIndex == 1)
        #expect(workflow.selectionRange == 1 ... 3)
    }

    @Test func extendSelectionUsesCurrentSelectionAsAnchorWhenNoneSet() {
        let workflow = makeWorkflow(photoCount: 5)
        workflow.selectedIndex = 2

        workflow.extendSelection(to: 4)

        #expect(workflow.selectionRange == 2 ... 4)
    }

    @Test func selectItemClearsExistingRange() {
        let workflow = makeWorkflow(photoCount: 5)

        workflow.selectItem(at: 1)
        workflow.extendSelection(to: 4)
        workflow.selectItem(at: 2)

        #expect(workflow.selectionRange == 2 ... 2)
    }

    @Test func selectionRangeIsNilWithNoSelection() {
        let workflow = makeWorkflow(photoCount: 5)
        workflow.selectedIndex = nil

        #expect(workflow.selectionRange == nil)
    }

    @Test func selectionRangeIsNilBeforeAnySelectItemCall() {
        let workflow = makeWorkflow(photoCount: 5)
        workflow.selectedIndex = 2

        #expect(workflow.selectionRange == nil)
    }

    @Test func applyMarkAndAdvancePreservesRangeForBulkMark() {
        let workflow = makeWorkflow(photoCount: 5)

        workflow.selectItem(at: 1)
        workflow.extendSelection(to: 3)
        workflow.applyMarkAndAdvance(.pick)

        #expect(workflow.selectionRange == 1 ... 3)
    }
}
