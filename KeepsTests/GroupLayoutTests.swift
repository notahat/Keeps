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

    @Test("The two most recently closed groups stay open")
    func twoMostRecentGroupsStayOpen() {
        let layout = GroupLayout(photoCount: 10, boundaries: [3, 5])

        #expect(layout.cells == (0 ..< 10).map { .photo($0) })
    }

    @Test("Older groups collapse into a single cell")
    func olderGroupsCollapse() {
        let layout = GroupLayout(photoCount: 10, boundaries: [3, 5, 8])

        #expect(layout.cells == [.collapsedGroup(0 ..< 3)] + (3 ..< 10).map { .photo($0) })
    }

    @Test("A boundary after the last photo closes the final group")
    func boundaryAfterLastPhotoClosesFinalGroup() {
        let layout = GroupLayout(photoCount: 10, boundaries: [3, 5, 10])

        #expect(layout.groups == [0 ..< 3, 3 ..< 5, 5 ..< 10])
        #expect(layout.cells.first == .collapsedGroup(0 ..< 3))
    }

    @Test("A collapsed group overlapping the expanded range shows its photos")
    func expandedRangeShowsCollapsedGroup() {
        let layout = GroupLayout(photoCount: 12, boundaries: [2, 4, 6, 8], expandedRange: 2 ..< 4)

        #expect(layout.cells == [.collapsedGroup(0 ..< 2)] + (2 ..< 12).map { .photo($0) })
    }

    @Test("A gap between cells maps to the photo after it, even past a collapsed group")
    func gapMapsToPhotoAfterIt() {
        let layout = GroupLayout(photoCount: 10, boundaries: [3, 5, 8])

        #expect(layout.photoIndex(forGap: 1) == 3)
        #expect(layout.photoIndex(forGap: 2) == 4)
    }

    @Test("The gap after the last cell maps to the end of the folder")
    func trailingGapMapsToEnd() {
        let layout = GroupLayout(photoCount: 10, boundaries: [3, 5, 8])

        #expect(layout.photoIndex(forGap: layout.cells.count) == 10)
    }

    @Test("The cell showing a photo is found whether or not its group is collapsed")
    func findsCellContainingPhoto() {
        let layout = GroupLayout(photoCount: 10, boundaries: [3, 5, 8])

        #expect(layout.cellIndex(containing: 1) == 0)
        #expect(layout.cellIndex(containing: 4) == 2)
    }
}
