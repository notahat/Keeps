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

    @Test("A gap has a boundary when the photo after it starts a group")
    func gapBoundaryLookup() {
        let layout = GroupLayout(photoCount: 10, boundaries: [3, 5, 8, 10])

        #expect(layout.hasBoundary(atGap: 1))
        // Cells: [collapsed 0..<3], [collapsed 3..<5], 5, 6, ... so gap 3
        // sits before photo 6.
        #expect(!layout.hasBoundary(atGap: 3))
        #expect(layout.hasBoundary(atGap: layout.cells.count))
    }

    @Test("Hidden photos are those folded into collapsed groups beyond their first")
    func hiddenPhotoCount() {
        let layout = GroupLayout(photoCount: 20, boundaries: [3, 7, 10, 12])

        // Groups 0..<3 and 3..<7 are collapsed, hiding 2 + 3 photos.
        #expect(layout.hiddenPhotoCount == 5)
    }

    @Test("With blank slots for the hidden photos, open photos keep their original columns")
    func openPhotosKeepColumns() {
        let layout = GroupLayout(photoCount: 30, boundaries: [3, 7, 10, 12])

        for columnCount in 2 ... 7 {
            let blanks = PhotoGridMetrics.blankSlotCount(for: layout.hiddenPhotoCount, columnCount: columnCount)
            for photoIndex in 7 ..< 30 {
                let slot = blanks + (layout.cellIndex(containing: photoIndex) ?? -1)
                #expect(slot % columnCount == photoIndex % columnCount)
            }
        }
    }

    @Test("The cell showing a photo is found whether or not its group is collapsed")
    func findsCellContainingPhoto() {
        let layout = GroupLayout(photoCount: 10, boundaries: [3, 5, 8])

        #expect(layout.cellIndex(containing: 1) == 0)
        #expect(layout.cellIndex(containing: 4) == 2)
    }
}
