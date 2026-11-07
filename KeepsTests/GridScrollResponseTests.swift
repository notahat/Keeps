import Foundation
@testable import Keeps
import Testing

struct GridScrollResponseTests {
    private let photoIDs = (0 ..< 6).map { _ in UUID() }

    /// Make cells showing some of the photos, by their indices in photoIDs.
    private func makeCells(
        showing photoIndices: [Int],
        selected selectedIndex: Int? = nil,
        stable stableIndex: Int? = nil
    ) -> GridScrolling.Cells {
        GridScrolling.Cells(
            photoIDs: photoIndices.map { photoIDs[$0] },
            selectedPhotoID: selectedIndex.map { photoIDs[$0] },
            stablePhotoID: stableIndex.map { photoIDs[$0] },
            leadingBlankSlots: 0
        )
    }

    @Test("A change to the cells holds the stable cell in place")
    func holdsStableCell() {
        let old = makeCells(showing: [0, 1, 2, 3, 4, 5], stable: 4)
        let new = makeCells(showing: [0, 4, 5], stable: 4)

        let response = GridScrollResponse.choose(from: old, to: new, pinnedCell: nil)

        #expect(response == .holdCell(atOldIndex: 4))
    }

    @Test("Without a stable cell, a change to the cells holds the pinned cell in place")
    func holdsPinnedCell() {
        let old = makeCells(showing: [0, 1, 2, 3, 4, 5])
        let new = makeCells(showing: [0, 4, 5])

        let response = GridScrollResponse.choose(
            from: old, to: new, pinnedCell: PinnedCell(index: 2, isFromClick: true)
        )

        #expect(response == .holdCell(atOldIndex: 2))
    }

    @Test("A change to the cells with nothing to hold leaves the view where it is")
    func staysWithNothingToHold() {
        let old = makeCells(showing: [0, 1, 2, 3, 4, 5])
        let new = makeCells(showing: [0, 4, 5])

        let response = GridScrollResponse.choose(from: old, to: new, pinnedCell: nil)

        #expect(response == .stay)
    }

    @Test("A change to the cells holds its place rather than following the selection")
    func holdingBeatsFollowing() {
        let old = makeCells(showing: [0, 1, 2, 3, 4, 5], selected: 1, stable: 4)
        let new = makeCells(showing: [0, 4, 5], selected: 4, stable: 4)

        let response = GridScrollResponse.choose(from: old, to: new, pinnedCell: nil)

        #expect(response == .holdCell(atOldIndex: 4))
    }

    @Test("A selection moved by a key press is followed")
    func followsKeyboardSelection() {
        let old = makeCells(showing: [0, 1, 2], selected: 0)
        let new = makeCells(showing: [0, 1, 2], selected: 2)

        let response = GridScrollResponse.choose(
            from: old, to: new, pinnedCell: PinnedCell(index: 1, isFromClick: false)
        )

        #expect(response == .followSelection(photoIDs[2]))
    }

    @Test("A selection moved by a click isn't followed, since the clicked cell is on screen")
    func ignoresClickedSelection() {
        let old = makeCells(showing: [0, 1, 2], selected: 0)
        let new = makeCells(showing: [0, 1, 2], selected: 2)

        let response = GridScrollResponse.choose(
            from: old, to: new, pinnedCell: PinnedCell(index: 2, isFromClick: true)
        )

        #expect(response == .stay)
    }

    @Test("A cleared selection isn't followed")
    func ignoresClearedSelection() {
        let old = makeCells(showing: [0, 1, 2], selected: 0)
        let new = makeCells(showing: [0, 1, 2])

        let response = GridScrollResponse.choose(from: old, to: new, pinnedCell: nil)

        #expect(response == .stay)
    }
}
