import Foundation
@testable import Keeps
import Testing

struct GroupingTests {
    @Test("Nothing is selected to begin with")
    func startsWithNothingSelected() {
        let grouping = makeGrouping(photoCount: 10)

        #expect(grouping.selectedPhotoIndex == nil)
        #expect(grouping.selectedCellIndex == nil)
    }

    @Test("Clearing the selection leaves nothing selected")
    func clearSelection() {
        let grouping = makeGrouping(photoCount: 10)
        grouping.selectCell(at: 4)

        grouping.clearSelection()

        #expect(grouping.selectedPhotoIndex == nil)
    }

    @Test("Toggling a gap places a boundary, and toggling it again removes it")
    func toggleGapAddsThenRemovesBoundary() {
        let grouping = makeGrouping(photoCount: 10)

        grouping.toggleBoundary(atGap: 3)
        let afterFirstToggle = grouping.boundaries
        grouping.toggleBoundary(atGap: 3)

        #expect(afterFirstToggle == [3])
        #expect(grouping.boundaries.isEmpty)
    }

    @Test("Boundaries before the first photo or past the end of the folder are ignored")
    func outOfRangeBoundariesIgnored() {
        let grouping = makeGrouping(photoCount: 10)

        grouping.toggleBoundary(atPhoto: 0)
        grouping.toggleBoundary(atPhoto: 11)

        #expect(grouping.boundaries.isEmpty)
    }

    @Test("The working point is the photo just after the last boundary")
    func workingPointFollowsLastBoundary() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 6])

        #expect(grouping.workingPointPhotoIndex == 6)
    }

    @Test("There is no working point before any boundary is placed or after the last photo is grouped")
    func noWorkingPoint() {
        let ungrouped = makeGrouping(photoCount: 10)
        let finished = makeGrouping(photoCount: 10, boundaries: [4, 10])

        #expect(ungrouped.workingPointPhotoIndex == nil)
        #expect(finished.workingPointPhotoIndex == nil)
    }

    @Test("Placing boundaries collapses nothing by itself")
    func boundariesAloneDoNotCollapse() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5, 8])

        #expect(grouping.layout.cells.allSatisfy { !$0.isCollapsed })
    }

    @Test("Collapsing collapses every group closed so far")
    func collapseClosesAllGroups() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5])

        grouping.collapseClosedGroups()

        #expect(grouping.layout.cells == [.collapsedGroup(0 ..< 3), .collapsedGroup(3 ..< 5)] + (5 ..< 10).map { .photo($0) })
    }

    @Test("Groups closed after collapsing stay open until the next collapse")
    func laterGroupsStayOpen() {
        let grouping = makeGrouping(photoCount: 10, collapsedBoundaries: [3])

        grouping.toggleBoundary(atPhoto: 6)

        #expect(grouping.layout.cells == [.collapsedGroup(0 ..< 3)] + (3 ..< 10).map { .photo($0) })
    }

    @Test("Collapsing with no boundaries does nothing")
    func collapseWithNoBoundaries() {
        let grouping = makeGrouping(photoCount: 10)

        grouping.collapseClosedGroups()

        #expect(grouping.layout.cells == (0 ..< 10).map { .photo($0) })
    }

    @Test("A gap after a collapsed group places the boundary at the right photo")
    func gapAfterCollapsedGroupMapsToPhoto() {
        let grouping = makeGrouping(photoCount: 12, collapsedBoundaries: [3], boundaries: [5, 8])

        // Cells: [collapsed 0..<3], 3, 4, 5, ... so gap 3 sits before photo 5.
        grouping.toggleBoundary(atGap: 3)

        #expect(grouping.boundaries == [3, 8])
    }

    @Test("Toggling a gap beside a collapsed group does nothing")
    func lockedGapIgnored() {
        let grouping = makeGrouping(photoCount: 10, collapsedBoundaries: [3], boundaries: [5, 8])

        // Cells: [collapsed 0..<3], 3, 4, ... so gap 1 is beside the collapsed
        // group.
        grouping.toggleBoundary(atGap: 1)

        #expect(grouping.boundaries == [3, 5, 8])
    }

    @Test("Selecting a collapsed group selects its first photo and leaves it collapsed")
    func selectingCollapsedGroupKeepsItCollapsed() {
        let grouping = makeGrouping(photoCount: 10, collapsedBoundaries: [3], boundaries: [5, 8])
        grouping.selectCell(at: 3)

        grouping.selectCell(at: 0)

        #expect(grouping.selectedPhotoIndex == 0)
        #expect(grouping.layout.cells.first == .collapsedGroup(0 ..< 3))
    }

    @Test("The selected cell is the collapsed group holding the selected photo")
    func selectedCellFollowsPhotoIntoCollapsedGroup() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5])
        grouping.selectCell(at: 1)

        grouping.collapseClosedGroups()

        #expect(grouping.selectedCellIndex == 0)
    }

    @Test("Each cell shows the first photo of its group or its own photo")
    func cellItemsAreFirstPhotos() {
        let grouping = makeGrouping(photoCount: 10, collapsedBoundaries: [3], boundaries: [5, 8])

        #expect(grouping.cellItems.first?.id == grouping.items[0].id)
        #expect(grouping.cellItems.count == 8)
    }

    @Test("Opening a group collapses every group up to and including it")
    func openingCollapsesUpToGroup() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5, 8])

        grouping.open(groupAtCell: 4)

        #expect(grouping.openGroup == 3 ..< 5)
        #expect(grouping.layout.cells == [.collapsedGroup(0 ..< 3), .collapsedGroup(3 ..< 5)] + (5 ..< 10).map { .photo($0) })
    }

    @Test("Opening an early group leaves later collapsed groups collapsed")
    func openingEarlyGroupKeepsLaterCollapsed() {
        let grouping = makeGrouping(photoCount: 10, collapsedBoundaries: [3, 5])

        grouping.open(groupAtCell: 0)

        #expect(grouping.openGroup == 0 ..< 3)
        #expect(grouping.layout.cells == [.collapsedGroup(0 ..< 3), .collapsedGroup(3 ..< 5)] + (5 ..< 10).map { .photo($0) })
    }

    @Test("Photos after the working point can't be opened")
    func ungroupedPhotosDoNotOpen() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3])

        grouping.open(groupAtCell: 5)

        #expect(grouping.openGroup == nil)
        #expect(grouping.layout.cells.allSatisfy { !$0.isCollapsed })
    }

    @Test("Toggling a keeper marks the photo, and toggling it again unmarks it")
    func toggleKeeper() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3])

        grouping.toggleKeeper(atPhoto: 1)
        let afterFirstToggle = grouping.keepers
        grouping.toggleKeeper(atPhoto: 1)

        #expect(afterFirstToggle == [1])
        #expect(grouping.keepers.isEmpty)
    }

    @Test("Finishing a group marks it done and opens the next group")
    func finishingOpensNextGroup() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5, 8])
        grouping.open(groupAtCell: 0)

        grouping.finishOpenGroup()

        #expect(grouping.isDone(0 ..< 3))
        #expect(grouping.openGroup == 3 ..< 5)
        #expect(grouping.layout.cells.prefix(2) == [.collapsedGroup(0 ..< 3), .collapsedGroup(3 ..< 5)])
    }

    @Test("Finishing a group skips later groups that are already done")
    func finishingSkipsDoneGroups() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5, 8])
        grouping.open(groupAtCell: 3)
        grouping.finishOpenGroup()
        grouping.open(groupAtCell: 0)

        grouping.finishOpenGroup()

        #expect(grouping.openGroup == 5 ..< 8)
    }

    @Test("Finishing the last group closes it")
    func finishingLastGroupCloses() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3])
        grouping.open(groupAtCell: 0)

        grouping.finishOpenGroup()

        #expect(grouping.isDone(0 ..< 3))
        #expect(grouping.openGroup == nil)
    }

    @Test("Closing a group leaves it not done")
    func closingLeavesGroupNotDone() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3])
        grouping.open(groupAtCell: 0)

        grouping.closeOpenGroup()

        #expect(grouping.openGroup == nil)
        #expect(!grouping.isDone(0 ..< 3))
    }

    @Test("A done group can be reopened, and stays done with its keepers")
    func reopeningDoneGroup() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3])
        grouping.open(groupAtCell: 0)
        grouping.toggleKeeper(atPhoto: 1)
        grouping.finishOpenGroup()

        grouping.open(groupAtCell: 0)

        #expect(grouping.openGroup == 0 ..< 3)
        #expect(grouping.isDone(0 ..< 3))
        #expect(grouping.keepers == [1])
    }
}
