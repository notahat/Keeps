import Foundation
@testable import Keeps
import Testing

struct GroupLayoutTests {
    @Test("With no boundaries there are no groups and every photo is shown")
    func noBoundaries() {
        let layout = GroupLayout(photoCount: 5, boundaries: [])

        #expect(layout.groups.isEmpty)
        #expect(layout.cells == (0 ..< 5).map { .photo($0) })
    }

    @Test("An empty folder has no groups and no cells, even with a stray boundary")
    func emptyFolder() {
        let layout = GroupLayout(photoCount: 0, boundaries: [3])

        #expect(layout.groups.isEmpty)
        #expect(layout.cells.isEmpty)
    }

    @Test("A boundary closes a group running from the start of the folder")
    func firstBoundaryClosesFirstGroup() {
        let layout = GroupLayout(photoCount: 10, boundaries: [3])

        #expect(layout.groups == [0 ..< 3])
    }

    @Test("Photos after the last boundary are not in any group")
    func photosAfterLastBoundaryAreUngrouped() {
        let layout = GroupLayout(photoCount: 10, boundaries: [3, 5])

        #expect(layout.groups == [0 ..< 3, 3 ..< 5])
    }

    @Test("A boundary after the last photo closes the final group")
    func boundaryAfterLastPhotoClosesFinalGroup() {
        let layout = GroupLayout(photoCount: 10, boundaries: [3, 5, 10])

        #expect(layout.groups == [0 ..< 3, 3 ..< 5, 5 ..< 10])
    }

    @Test("Closed groups stay open until collapsed")
    func groupsStayOpenUntilCollapsed() {
        let layout = GroupLayout(photoCount: 10, boundaries: [3, 5, 8])

        #expect(layout.cells == (0 ..< 10).map { .photo($0) })
    }

    @Test("Groups ending at or before the collapse point collapse into single cells")
    func groupsUpToCollapsePointCollapse() {
        let layout = GroupLayout(photoCount: 10, boundaries: [3, 5, 8], collapsedUpTo: 5)

        #expect(layout.cells == [.collapsedGroup(0 ..< 3), .collapsedGroup(3 ..< 5)] + (5 ..< 10).map { .photo($0) })
    }

    @Test("A gap between cells maps to the photo after it, even past a collapsed group")
    func gapMapsToPhotoAfterIt() {
        let layout = GroupLayout(photoCount: 10, boundaries: [3, 5, 8], collapsedUpTo: 3)

        #expect(layout.photoIndex(forGap: 1) == 3)
        #expect(layout.photoIndex(forGap: 2) == 4)
    }

    @Test("The gap after the last cell maps to the end of the folder")
    func trailingGapMapsToEnd() {
        let layout = GroupLayout(photoCount: 10, boundaries: [3, 5, 8], collapsedUpTo: 3)

        #expect(layout.photoIndex(forGap: layout.cells.count) == 10)
    }

    @Test("A gap has a boundary when the photo after it starts a group")
    func gapBoundaryLookup() {
        let layout = GroupLayout(photoCount: 10, boundaries: [3, 5, 8, 10], collapsedUpTo: 5)

        #expect(layout.hasBoundary(atGap: 1))
        // Cells: [collapsed 0..<3], [collapsed 3..<5], 5, 6, ... so gap 3
        // sits before photo 6.
        #expect(!layout.hasBoundary(atGap: 3))
        #expect(layout.hasBoundary(atGap: layout.cells.count))
    }

    @Test("Hidden photos are those folded into collapsed groups beyond their first")
    func hiddenPhotoCount() {
        let layout = GroupLayout(photoCount: 20, boundaries: [3, 7, 10, 12], collapsedUpTo: 7)

        // Groups 0..<3 and 3..<7 are collapsed, hiding 2 + 3 photos.
        #expect(layout.hiddenPhotoCount == 5)
    }

    @Test("With blank slots for the hidden photos, open photos keep their original columns")
    func openPhotosKeepColumns() {
        let layout = GroupLayout(photoCount: 30, boundaries: [3, 7, 10, 12], collapsedUpTo: 7)

        for columnCount in 2 ... 7 {
            let blanks = PhotoGridMetrics.blankSlotCount(for: layout.hiddenPhotoCount, columnCount: columnCount)
            for photoIndex in 7 ..< 30 {
                let slot = blanks + (layout.cellIndex(containing: photoIndex) ?? -1)
                #expect(slot % columnCount == photoIndex % columnCount)
            }
        }
    }

    @Test("Gaps beside a collapsed group can't be edited")
    func gapsBesideCollapsedGroupsAreLocked() {
        let layout = GroupLayout(photoCount: 10, boundaries: [3, 5, 8], collapsedUpTo: 3)

        // Cells: [collapsed 0..<3], 3, 4, ... so gap 1 sits right after the
        // collapsed group.
        #expect(!layout.isGapEditable(1))
        #expect(layout.isGapEditable(2))
    }

    @Test("The gap before the first cell can't be edited")
    func leadingGapIsLocked() {
        let layout = GroupLayout(photoCount: 10, boundaries: [])

        #expect(!layout.isGapEditable(0))
    }

    @Test("The gap after the last cell can be edited")
    func trailingGapIsEditable() {
        let layout = GroupLayout(photoCount: 10, boundaries: [3, 5, 8], collapsedUpTo: 3)

        #expect(layout.isGapEditable(layout.cells.count))
    }

    @Test("The cell showing a photo is found whether or not its group is collapsed")
    func findsCellContainingPhoto() {
        let layout = GroupLayout(photoCount: 10, boundaries: [3, 5, 8], collapsedUpTo: 3)

        #expect(layout.cellIndex(containing: 1) == 0)
        #expect(layout.cellIndex(containing: 4) == 2)
    }

    @Test("Done groups leave the grid, but are still groups")
    func doneGroupsLeaveGrid() {
        let layout = GroupLayout(photoCount: 10, boundaries: [3, 5, 8], collapsedUpTo: 5, doneGroupStarts: [0])

        #expect(layout.cells.prefix(2) == [.collapsedGroup(3 ..< 5), .photo(5)])
        #expect(layout.groups == [0 ..< 3, 3 ..< 5, 5 ..< 8])
    }

    @Test("A done group's photos all count as hidden")
    func doneGroupPhotosHidden() {
        let layout = GroupLayout(photoCount: 10, boundaries: [3, 5, 8], collapsedUpTo: 5, doneGroupStarts: [0])

        // All 3 photos of the done group, and 1 of the collapsed 3..<5.
        #expect(layout.hiddenPhotoCount == 4)
    }

    @Test("The gaps where done groups were stay locked")
    func gapsWhereDoneGroupsWereStayLocked() {
        let afterCollapsed = GroupLayout(photoCount: 10, boundaries: [3, 5, 8], collapsedUpTo: 5, doneGroupStarts: [3])
        let atStart = GroupLayout(photoCount: 10, boundaries: [3, 5, 8], collapsedUpTo: 5, doneGroupStarts: [0, 3])

        // Cells: [collapsed 0..<3], 5, 6, ... and then 5, 6, ...
        #expect(!afterCollapsed.isGapEditable(1))
        #expect(!atStart.isGapEditable(0))
        #expect(atStart.isGapEditable(1))
    }

    @Test("A done group that isn't collapsed stays in the grid")
    func uncollapsedDoneGroupStays() {
        let layout = GroupLayout(photoCount: 10, boundaries: [3, 5], collapsedUpTo: 0, doneGroupStarts: [0])

        #expect(layout.cells.first == .photo(0))
    }
}
