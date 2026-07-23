import Foundation
@testable import Keeps
import Testing

struct SelectionTests {
    @Test func selectItemSetsSelectionAndCollapsesPreviousRange() throws {
        let workflow = makeWorkflow(photoCount: 5)

        workflow.selectItem(at: 2)

        #expect(workflow.selectedIndex == 2)
        #expect(workflow.selectionRange == 2 ... 2)
    }

    @Test func extendSelectionForwardFromAnchor() throws {
        let workflow = makeWorkflow(photoCount: 5)

        workflow.selectItem(at: 1)
        workflow.extendSelection(to: 3)

        #expect(workflow.selectedIndex == 3)
        #expect(workflow.selectionRange == 1 ... 3)
    }

    @Test func extendSelectionBackwardFromAnchor() throws {
        let workflow = makeWorkflow(photoCount: 5)

        workflow.selectItem(at: 3)
        workflow.extendSelection(to: 1)

        #expect(workflow.selectedIndex == 1)
        #expect(workflow.selectionRange == 1 ... 3)
    }

    @Test func extendSelectionUsesCurrentSelectionAsAnchorWhenNoneSet() throws {
        let workflow = makeWorkflow(photoCount: 5)
        workflow.selectedIndex = 2

        workflow.extendSelection(to: 4)

        #expect(workflow.selectionRange == 2 ... 4)
    }

    @Test func selectItemClearsExistingRange() throws {
        let workflow = makeWorkflow(photoCount: 5)

        workflow.selectItem(at: 1)
        workflow.extendSelection(to: 4)
        workflow.selectItem(at: 2)

        #expect(workflow.selectionRange == 2 ... 2)
    }

    @Test func selectionRangeIsNilWithNoSelection() throws {
        let workflow = makeWorkflow(photoCount: 5)
        workflow.selectedIndex = nil

        #expect(workflow.selectionRange == nil)
    }

    @Test func selectionRangeIsNilBeforeAnySelectItemCall() throws {
        let workflow = makeWorkflow(photoCount: 5)
        workflow.selectedIndex = 2

        #expect(workflow.selectionRange == nil)
    }

    @Test func applyMarkAndAdvancePreservesRangeForBulkMark() throws {
        let workflow = makeWorkflow(photoCount: 5)

        workflow.selectItem(at: 1)
        workflow.extendSelection(to: 3)
        workflow.applyMarkAndAdvance(.pick)

        #expect(workflow.selectionRange == 1 ... 3)
    }

    @Test func applyFilterClearsRange() throws {
        let workflow = makeWorkflow(photoCount: 5)

        workflow.selectItem(at: 1)
        workflow.extendSelection(to: 3)
        workflow.applyFilter(.all)

        #expect(workflow.selectionRange == nil)
    }
}
