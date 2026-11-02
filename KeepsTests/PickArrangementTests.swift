@testable import Keeps
import Testing

struct PickArrangementTests {
    @Test("A group that isn't done shows every photo as a tile")
    func notDoneShowsAll() {
        let arrangement = PickArrangement(group: 10 ..< 14, keepers: [11], isDone: false)

        #expect(arrangement.tilePhotos == [10, 11, 12, 13])
        #expect(arrangement.pilePhotos.isEmpty)
    }

    @Test("A done group shows its keepers as tiles and piles up the rest")
    func donePilesNonKeepers() {
        let arrangement = PickArrangement(group: 10 ..< 15, keepers: [13, 11], isDone: true)

        #expect(arrangement.tilePhotos == [11, 13])
        #expect(arrangement.pilePhotos == [10, 12, 14])
    }

    @Test("Keepers outside the group are ignored")
    func keepersOutsideGroupIgnored() {
        let arrangement = PickArrangement(group: 10 ..< 13, keepers: [2, 11, 20], isDone: true)

        #expect(arrangement.tilePhotos == [11])
        #expect(arrangement.pilePhotos == [10, 12])
    }

    @Test("A done group with no keepers is all pile")
    func doneWithNoKeepers() {
        let arrangement = PickArrangement(group: 10 ..< 13, keepers: [], isDone: true)

        #expect(arrangement.tilePhotos.isEmpty)
        #expect(arrangement.pilePhotos == [10, 11, 12])
    }

    @Test("Focus stays on a photo that is still a tile")
    func focusStaysOnTile() {
        let arrangement = PickArrangement(group: 10 ..< 15, keepers: [11, 13], isDone: true)

        #expect(arrangement.tileIndex(nearestPhoto: 13) == 1)
    }

    @Test("Focus on a piled photo moves to the nearest tile before it")
    func focusMovesToEarlierTile() {
        let arrangement = PickArrangement(group: 10 ..< 15, keepers: [11, 13], isDone: true)

        #expect(arrangement.tileIndex(nearestPhoto: 14) == 1)
    }

    @Test("Focus before every tile moves to the first tile")
    func focusMovesToFirstTile() {
        let arrangement = PickArrangement(group: 10 ..< 15, keepers: [11, 13], isDone: true)

        #expect(arrangement.tileIndex(nearestPhoto: 10) == 0)
    }

    @Test("There is nowhere to focus when there are no tiles")
    func noFocusWithoutTiles() {
        let arrangement = PickArrangement(group: 10 ..< 13, keepers: [], isDone: true)

        #expect(arrangement.tileIndex(nearestPhoto: 11) == nil)
    }
}
