import Foundation
@testable import Keeps
import Testing

struct GroupCullWorkflowTests {
    @Test("Toggling a gap places a boundary, and toggling it again removes it")
    func toggleGapAddsThenRemovesBoundary() {
        let workflow = makeGroupCullWorkflow(photoCount: 10)

        workflow.toggleBoundary(atGap: 3)
        let afterFirstToggle = workflow.boundaries
        workflow.toggleBoundary(atGap: 3)

        #expect(afterFirstToggle == [3])
        #expect(workflow.boundaries.isEmpty)
    }

    @Test("Boundaries before the first photo or past the end of the folder are ignored")
    func outOfRangeBoundariesIgnored() {
        let workflow = makeGroupCullWorkflow(photoCount: 10)

        workflow.toggleBoundary(atPhoto: 0)
        workflow.toggleBoundary(atPhoto: 11)

        #expect(workflow.boundaries.isEmpty)
    }

    @Test("A gap after a collapsed group places the boundary at the right photo")
    func gapAfterCollapsedGroupMapsToPhoto() {
        let workflow = makeGroupCullWorkflow(photoCount: 12, boundaries: [3, 5, 8])

        // Cells: [collapsed 0..<3], 3, 4, 5, ... so gap 3 sits before photo 5.
        workflow.toggleBoundary(atGap: 3)

        #expect(workflow.boundaries == [3, 8])
    }

    @Test("Removing the last boundary re-expands the group it collapsed")
    func removingLastBoundaryReExpands() {
        let workflow = makeGroupCullWorkflow(photoCount: 10, boundaries: [3, 5, 8])

        // Cells: [collapsed 0..<3], 3, 4, 5, 6, 7, 8 so gap 6 sits before photo 8.
        workflow.toggleBoundary(atGap: 6)

        #expect(workflow.layout.cells.first == .photo(0))
    }

    @Test("Tapping a collapsed group expands it and selects its first photo")
    func tappingCollapsedGroupExpandsIt() {
        let workflow = makeGroupCullWorkflow(photoCount: 10, boundaries: [3, 5, 8])

        workflow.tapCell(at: 0)

        #expect(workflow.expandedRange == 0 ..< 3)
        #expect(workflow.selectedPhotoIndex == 0)
        #expect(workflow.layout.cells.first == .photo(0))
    }

    @Test("Tapping a photo inside the expanded group keeps it expanded")
    func tappingInsideKeepsExpansion() {
        let workflow = makeGroupCullWorkflow(photoCount: 10, boundaries: [3, 5, 8])
        workflow.tapCell(at: 0)

        workflow.tapCell(at: 2)

        #expect(workflow.expandedRange == 0 ..< 3)
        #expect(workflow.selectedPhotoIndex == 2)
    }

    @Test("Tapping a photo outside the expanded group collapses it again")
    func tappingOutsideCollapses() {
        let workflow = makeGroupCullWorkflow(photoCount: 10, boundaries: [3, 5, 8])
        workflow.tapCell(at: 0)

        workflow.tapCell(at: 6)

        #expect(workflow.expandedRange == nil)
        #expect(workflow.selectedPhotoIndex == 6)
    }

    @Test("Placing a boundary inside the expanded group keeps it expanded")
    func boundaryInsideKeepsExpansion() {
        let workflow = makeGroupCullWorkflow(photoCount: 10, boundaries: [3, 5, 8])
        workflow.tapCell(at: 0)

        workflow.toggleBoundary(atGap: 1)

        #expect(workflow.boundaries == [1, 3, 5, 8])
        #expect(workflow.expandedRange == 0 ..< 3)
    }

    @Test("Placing a boundary outside the expanded group collapses it again")
    func boundaryOutsideCollapses() {
        let workflow = makeGroupCullWorkflow(photoCount: 10, boundaries: [3, 5, 8])
        workflow.tapCell(at: 0)

        workflow.toggleBoundary(atGap: 9)

        #expect(workflow.expandedRange == nil)
    }

    @Test("The selected cell is the collapsed group holding the selected photo")
    func selectedCellFollowsPhotoIntoCollapsedGroup() {
        let workflow = makeGroupCullWorkflow(photoCount: 10, boundaries: [3, 5])
        workflow.tapCell(at: 1)

        workflow.toggleBoundary(atGap: 8)

        #expect(workflow.selectedCellIndex == 0)
    }

    @Test("Displayed items are the first photo of each cell")
    func displayedItemsAreCellRepresentatives() {
        let workflow = makeGroupCullWorkflow(photoCount: 10, boundaries: [3, 5, 8])

        #expect(workflow.displayedItems.first?.id == workflow.items[0].id)
        #expect(workflow.displayedItems.count == 8)
    }
}
