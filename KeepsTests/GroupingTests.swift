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

    @Test("Toggling a gap places a boundary there")
    func toggleGapAddsBoundary() {
        let grouping = makeGrouping(photoCount: 10)

        grouping.toggleBoundary(atGap: 3)

        #expect(grouping.boundaries == [3])
    }

    @Test("Toggling a gap with a boundary removes the boundary")
    func toggleGapRemovesBoundary() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3])

        grouping.toggleBoundary(atGap: 3)

        #expect(grouping.boundaries.isEmpty)
    }

    @Test("The working point is the photo just after the last boundary")
    func workingPointFollowsLastBoundary() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 6])

        #expect(grouping.workingPointPhotoIndex == 6)
    }

    @Test("There is no working point before any boundary is placed")
    func noWorkingPointBeforeBoundaries() {
        let grouping = makeGrouping(photoCount: 10)

        #expect(grouping.workingPointPhotoIndex == nil)
    }

    @Test("There is no working point once the last photo is grouped")
    func noWorkingPointWhenAllGrouped() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [4, 10])

        #expect(grouping.workingPointPhotoIndex == nil)
    }

    @Test("Placing boundaries collapses nothing by itself")
    func boundariesAloneDoNotCollapse() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5, 8])

        #expect(grouping.layout.cells.allSatisfy { !$0.isCollapsed })
    }

    @Test("Collapsing collapses every group")
    func collapseCollapsesAllGroups() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5])

        grouping.collapseGroups()

        #expect(grouping.layout.cells == [.collapsedGroup(0 ..< 3), .collapsedGroup(3 ..< 5)] + (5 ..< 10).map { .photo($0) })
    }

    @Test("Groups made after collapsing stay uncollapsed until the next collapse")
    func laterGroupsStayUncollapsed() {
        let grouping = makeGrouping(photoCount: 10, collapsedBoundaries: [3])

        grouping.toggleBoundary(atPhoto: 6)

        #expect(grouping.layout.cells == [.collapsedGroup(0 ..< 3)] + (3 ..< 10).map { .photo($0) })
    }

    @Test("Collapsing with no boundaries does nothing")
    func collapseWithNoBoundaries() {
        let grouping = makeGrouping(photoCount: 10)

        grouping.collapseGroups()

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

    @Test("Selecting a collapsed group selects its first photo")
    func selectingCollapsedGroupSelectsFirstPhoto() {
        let grouping = makeGrouping(photoCount: 10, collapsedBoundaries: [3], boundaries: [5, 8])
        grouping.selectCell(at: 3)

        grouping.selectCell(at: 0)

        #expect(grouping.selectedPhotoIndex == 0)
    }

    @Test("Selecting a collapsed group leaves it collapsed")
    func selectingCollapsedGroupKeepsItCollapsed() {
        let grouping = makeGrouping(photoCount: 10, collapsedBoundaries: [3], boundaries: [5, 8])
        grouping.selectCell(at: 3)

        grouping.selectCell(at: 0)

        #expect(grouping.layout.cells.first == .collapsedGroup(0 ..< 3))
    }

    @Test("The selected cell is the collapsed group holding the selected photo")
    func selectedCellFollowsPhotoIntoCollapsedGroup() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5])
        grouping.selectCell(at: 1)

        grouping.collapseGroups()

        #expect(grouping.selectedCellIndex == 0)
    }

    @Test("Each cell shows the first photo of its group or its own photo")
    func cellPhotosAreFirstPhotos() {
        let grouping = makeGrouping(photoCount: 10, collapsedBoundaries: [3], boundaries: [5, 8])

        // Cells: [collapsed 0..<3], 3, 4, ... 9.
        #expect(grouping.cellPhotos.map(\.id) == ([0] + Array(3 ..< 10)).map { grouping.photos[$0].id })
    }

    @Test("Opening a cell opens the group holding its photo")
    func openingOpensGroup() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5, 8])

        grouping.open(groupAtCell: 4)

        #expect(grouping.openGroup == 3 ..< 5)
    }

    @Test("Opening a group collapses every group up to and including it")
    func openingCollapsesUpToGroup() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5, 8])

        grouping.open(groupAtCell: 4)

        #expect(grouping.layout.cells == [.collapsedGroup(0 ..< 3), .collapsedGroup(3 ..< 5)] + (5 ..< 10).map { .photo($0) })
    }

    @Test("Opening a group selects it, so the sort screen shows it on return")
    func openingSelectsGroup() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5, 8])

        grouping.open(groupAtCell: 4)

        #expect(grouping.selectedPhotoIndex == 3)
    }

    @Test("Opening an early group leaves later collapsed groups collapsed")
    func openingEarlyGroupKeepsLaterCollapsed() {
        let grouping = makeGrouping(photoCount: 10, collapsedBoundaries: [3, 5])

        grouping.open(groupAtCell: 0)

        #expect(grouping.layout.cells == [.collapsedGroup(0 ..< 3), .collapsedGroup(3 ..< 5)] + (5 ..< 10).map { .photo($0) })
    }

    @Test("Photos after the working point can't be opened")
    func ungroupedPhotosDoNotOpen() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3])

        grouping.open(groupAtCell: 5)

        #expect(grouping.openGroup == nil)
    }

    @Test("Trying to open photos after the working point collapses nothing")
    func ungroupedPhotosCollapseNothing() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3])

        grouping.open(groupAtCell: 5)

        #expect(grouping.layout.cells.allSatisfy { !$0.isCollapsed })
    }

    @Test("Toggling a photo that isn't a keeper makes it one")
    func toggleKeeperAdds() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3])

        grouping.toggleKeeper(atPhoto: 1)

        #expect(grouping.keepers == [1])
    }

    @Test("Toggling a keeper makes it not a keeper")
    func toggleKeeperRemoves() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3])
        grouping.toggleKeeper(atPhoto: 1)

        grouping.toggleKeeper(atPhoto: 1)

        #expect(grouping.keepers.isEmpty)
    }

    @Test("Counts only the keepers inside a group")
    func keptCountInGroup() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 6])
        for photoIndex in [1, 3, 5, 8] {
            grouping.toggleKeeper(atPhoto: photoIndex)
        }

        let keptCount = grouping.keptCount(in: 3 ..< 6)

        #expect(keptCount == 2)
    }

    @Test("Marking the open group done makes it done")
    func markingDone() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5, 8])
        grouping.open(groupAtCell: 0)

        grouping.markOpenGroupDone()

        #expect(grouping.isDone(0 ..< 3))
    }

    @Test("Marking the open group done leaves it open")
    func markingDoneLeavesGroupOpen() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5, 8])
        grouping.open(groupAtCell: 0)

        grouping.markOpenGroupDone()

        #expect(grouping.openGroup == 0 ..< 3)
    }

    @Test("Un-marking the open group makes it not done")
    func unmarkingDone() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5])
        grouping.open(groupAtCell: 0)
        grouping.markOpenGroupDone()

        grouping.markOpenGroupNotDone()

        #expect(!grouping.isDone(0 ..< 3))
    }

    @Test("Un-marking the open group leaves it open")
    func unmarkingDoneLeavesGroupOpen() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5])
        grouping.open(groupAtCell: 0)
        grouping.markOpenGroupDone()

        grouping.markOpenGroupNotDone()

        #expect(grouping.openGroup == 0 ..< 3)
    }

    @Test("An un-marked group comes back to the grid")
    func unmarkedGroupReturnsToGrid() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5])
        grouping.open(groupAtCell: 0)
        grouping.markOpenGroupDone()

        grouping.markOpenGroupNotDone()

        #expect(grouping.layout.cells.first == .collapsedGroup(0 ..< 3))
    }

    @Test("Closing the open group leaves no group open")
    func closingClosesGroup() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3])
        grouping.open(groupAtCell: 0)

        grouping.closeOpenGroup()

        #expect(grouping.openGroup == nil)
    }

    @Test("Closing a group leaves it not done")
    func closingLeavesGroupNotDone() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3])
        grouping.open(groupAtCell: 0)

        grouping.closeOpenGroup()

        #expect(!grouping.isDone(0 ..< 3))
    }

    @Test("Closing a group that isn't done leaves it selected")
    func closingUnfinishedGroupKeepsSelection() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5])
        grouping.open(groupAtCell: 0)

        grouping.closeOpenGroup()

        #expect(grouping.selectedPhotoIndex == 0)
    }

    @Test("Closing a done group selects the next group that isn't done")
    func closingDoneGroupSelectsNext() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5, 8])
        grouping.open(groupAtCell: 3)
        grouping.markOpenGroupDone()
        grouping.closeOpenGroup()
        grouping.open(groupAtCell: 0)
        grouping.markOpenGroupDone()

        grouping.closeOpenGroup()

        #expect(grouping.selectedPhotoIndex == 5)
    }

    @Test("Closing the last done group selects the working point")
    func closingLastDoneGroupSelectsWorkingPoint() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3])
        grouping.open(groupAtCell: 0)
        grouping.markOpenGroupDone()

        grouping.closeOpenGroup()

        #expect(grouping.selectedPhotoIndex == 3)
    }

    @Test("Closing a done group with nothing left to group selects nothing")
    func closingDoneGroupWithNothingLeft() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [10])
        grouping.open(groupAtCell: 0)
        grouping.markOpenGroupDone()

        grouping.closeOpenGroup()

        #expect(grouping.selectedPhotoIndex == nil)
    }

    @Test("Closing a done group remembers it as the last opened")
    func closingDoneGroupRemembersIt() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5, 8])
        grouping.open(groupAtCell: 0)
        grouping.markOpenGroupDone()

        grouping.closeOpenGroup()

        #expect(grouping.lastOpenedGroup == 0 ..< 3)
    }

    @Test("A group's number is its place among the groups, counting from one")
    func groupNumber() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5, 8])

        #expect(grouping.groupNumber(of: 3 ..< 5) == 2)
    }

    @Test("A done group leaves the grid")
    func doneGroupLeavesGrid() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5])
        grouping.open(groupAtCell: 0)

        grouping.markOpenGroupDone()

        #expect(grouping.layout.cells.first == .photo(3))
    }

    @Test("The keepers of done groups come latest group first, each in order")
    func keepersOfDoneGroups() {
        let grouping = makeGrouping(photoCount: 12, boundaries: [3, 6, 9])
        for keeper in [1, 2, 4, 7] {
            grouping.toggleKeeper(atPhoto: keeper)
        }

        finishFirstGroupInGrid(of: grouping)
        finishFirstGroupInGrid(of: grouping)

        #expect(grouping.keepersOfDoneGroups == [4, 1, 2])
    }

    @Test("The photos set aside from done groups come latest group first, each in order")
    func setAsideFromDoneGroups() {
        let grouping = makeGrouping(photoCount: 12, boundaries: [3, 6, 9])
        for keeper in [1, 2, 4, 7] {
            grouping.toggleKeeper(atPhoto: keeper)
        }

        finishFirstGroupInGrid(of: grouping)
        finishFirstGroupInGrid(of: grouping)

        #expect(grouping.setAsideFromDoneGroups == [3, 5, 0])
    }

    @Test("The done groups come latest first")
    func doneGroupsLatestFirst() {
        let grouping = makeGrouping(photoCount: 12, boundaries: [3, 6, 9])

        finishFirstGroupInGrid(of: grouping)
        finishFirstGroupInGrid(of: grouping)

        #expect(grouping.doneGroups == [3 ..< 6, 0 ..< 3])
    }

    @Test("The photos to go are those not in done groups, in folder order")
    func photosToGo() {
        let grouping = makeGrouping(photoCount: 8, boundaries: [3, 5])

        finishFirstGroupInGrid(of: grouping)

        #expect(grouping.photosToGo == [3, 4, 5, 6, 7])
    }

    @Test("The folder is all done once every photo is in a done group")
    func allDone() {
        let grouping = makeGrouping(photoCount: 5, boundaries: [3, 5])

        finishFirstGroupInGrid(of: grouping)
        finishFirstGroupInGrid(of: grouping)

        #expect(grouping.isAllDone)
    }

    @Test("The folder isn't all done while some photos are still ungrouped")
    func notAllDoneWithUngroupedPhotos() {
        let grouping = makeGrouping(photoCount: 8, boundaries: [3, 5])

        finishFirstGroupInGrid(of: grouping)
        finishFirstGroupInGrid(of: grouping)

        #expect(!grouping.isAllDone)
    }

    @Test("A done group can be opened directly")
    func openingDoneGroupDirectly() {
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 5])
        finishFirstGroupInGrid(of: grouping)

        grouping.open(0 ..< 3)

        #expect(grouping.openGroup == 0 ..< 3)
    }

    @Test("Done groups are counted")
    func doneGroupCount() {
        let grouping = makeGrouping(photoCount: 12, boundaries: [3, 6, 9])

        finishFirstGroupInGrid(of: grouping)
        finishFirstGroupInGrid(of: grouping)

        #expect(grouping.doneGroupCount == 2)
    }

    /// Open the group of the grid's first cell, mark it done, and close it,
    /// as the screens would.
    private func finishFirstGroupInGrid(of grouping: Grouping) {
        grouping.open(groupAtCell: 0)
        grouping.markOpenGroupDone()
        grouping.closeOpenGroup()
    }
}
