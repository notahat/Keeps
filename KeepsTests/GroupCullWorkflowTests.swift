import Foundation
@testable import Keeps
import Testing

struct GroupCullWorkflowTests {
    @Test("Nothing is selected to begin with")
    func startsWithNothingSelected() {
        let workflow = makeGroupCullWorkflow(photoCount: 10)

        #expect(workflow.selectedPhotoIndex == nil)
        #expect(workflow.selectedCellIndex == nil)
    }

    @Test("Clearing the selection leaves nothing selected")
    func clearSelection() {
        let workflow = makeGroupCullWorkflow(photoCount: 10)
        workflow.selectCell(at: 4)

        workflow.clearSelection()

        #expect(workflow.selectedPhotoIndex == nil)
    }

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

    @Test("The working point is the photo just after the last boundary")
    func workingPointFollowsLastBoundary() {
        let workflow = makeGroupCullWorkflow(photoCount: 10, boundaries: [3, 6])

        #expect(workflow.workingPointPhotoIndex == 6)
    }

    @Test("There is no working point before any boundary is placed or after the last photo is grouped")
    func noWorkingPoint() {
        let ungrouped = makeGroupCullWorkflow(photoCount: 10)
        let finished = makeGroupCullWorkflow(photoCount: 10, boundaries: [4, 10])

        #expect(ungrouped.workingPointPhotoIndex == nil)
        #expect(finished.workingPointPhotoIndex == nil)
    }

    @Test("Placing boundaries collapses nothing by itself")
    func boundariesAloneDoNotCollapse() {
        let workflow = makeGroupCullWorkflow(photoCount: 10, boundaries: [3, 5, 8])

        #expect(workflow.layout.cells.allSatisfy { !$0.isCollapsed })
    }

    @Test("Collapsing collapses every group closed so far")
    func collapseClosesAllGroups() {
        let workflow = makeGroupCullWorkflow(photoCount: 10, boundaries: [3, 5])

        workflow.collapseClosedGroups()

        #expect(workflow.layout.cells == [.collapsedGroup(0 ..< 3), .collapsedGroup(3 ..< 5)] + (5 ..< 10).map { .photo($0) })
    }

    @Test("Groups closed after collapsing stay open until the next collapse")
    func laterGroupsStayOpen() {
        let workflow = makeGroupCullWorkflow(photoCount: 10, collapsedBoundaries: [3])

        workflow.toggleBoundary(atPhoto: 6)

        #expect(workflow.layout.cells == [.collapsedGroup(0 ..< 3)] + (3 ..< 10).map { .photo($0) })
    }

    @Test("Collapsing with no boundaries does nothing")
    func collapseWithNoBoundaries() {
        let workflow = makeGroupCullWorkflow(photoCount: 10)

        workflow.collapseClosedGroups()

        #expect(workflow.layout.cells == (0 ..< 10).map { .photo($0) })
    }

    @Test("A gap after a collapsed group places the boundary at the right photo")
    func gapAfterCollapsedGroupMapsToPhoto() {
        let workflow = makeGroupCullWorkflow(photoCount: 12, collapsedBoundaries: [3], boundaries: [5, 8])

        // Cells: [collapsed 0..<3], 3, 4, 5, ... so gap 3 sits before photo 5.
        workflow.toggleBoundary(atGap: 3)

        #expect(workflow.boundaries == [3, 8])
    }

    @Test("Toggling a gap beside a collapsed group does nothing")
    func lockedGapIgnored() {
        let workflow = makeGroupCullWorkflow(photoCount: 10, collapsedBoundaries: [3], boundaries: [5, 8])

        // Cells: [collapsed 0..<3], 3, 4, ... so gap 1 is beside the collapsed
        // group.
        workflow.toggleBoundary(atGap: 1)

        #expect(workflow.boundaries == [3, 5, 8])
    }

    @Test("Selecting a collapsed group selects its first photo and leaves it collapsed")
    func selectingCollapsedGroupKeepsItCollapsed() {
        let workflow = makeGroupCullWorkflow(photoCount: 10, collapsedBoundaries: [3], boundaries: [5, 8])
        workflow.selectCell(at: 3)

        workflow.selectCell(at: 0)

        #expect(workflow.selectedPhotoIndex == 0)
        #expect(workflow.layout.cells.first == .collapsedGroup(0 ..< 3))
    }

    @Test("The selected cell is the collapsed group holding the selected photo")
    func selectedCellFollowsPhotoIntoCollapsedGroup() {
        let workflow = makeGroupCullWorkflow(photoCount: 10, boundaries: [3, 5])
        workflow.selectCell(at: 1)

        workflow.collapseClosedGroups()

        #expect(workflow.selectedCellIndex == 0)
    }

    @Test("Displayed items are the first photo of each cell")
    func displayedItemsAreCellRepresentatives() {
        let workflow = makeGroupCullWorkflow(photoCount: 10, collapsedBoundaries: [3], boundaries: [5, 8])

        #expect(workflow.displayedItems.first?.id == workflow.items[0].id)
        #expect(workflow.displayedItems.count == 8)
    }
}
