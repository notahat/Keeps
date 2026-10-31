@testable import Keeps
import Testing

struct PickArrangementTests {
    @Test("A group that isn't done shows every photo as a tile")
    func notDoneShowsAll() {
        let arrangement = PickArrangement(photoCount: 4, keeperPlaces: [1], isDone: false)

        #expect(arrangement.tilePlaces == [0, 1, 2, 3])
        #expect(arrangement.pilePlaces.isEmpty)
    }

    @Test("A done group shows its keepers as tiles and piles up the rest")
    func donePilesNonKeepers() {
        let arrangement = PickArrangement(photoCount: 5, keeperPlaces: [3, 1], isDone: true)

        #expect(arrangement.tilePlaces == [1, 3])
        #expect(arrangement.pilePlaces == [0, 2, 4])
    }

    @Test("A done group with no keepers is all pile")
    func doneWithNoKeepers() {
        let arrangement = PickArrangement(photoCount: 3, keeperPlaces: [], isDone: true)

        #expect(arrangement.tilePlaces.isEmpty)
        #expect(arrangement.pilePlaces == [0, 1, 2])
    }

    @Test("Focus stays on a photo that is still a tile")
    func focusStaysOnTile() {
        let arrangement = PickArrangement(photoCount: 5, keeperPlaces: [1, 3], isDone: true)

        #expect(arrangement.tileIndex(nearestPlace: 3) == 1)
    }

    @Test("Focus on a piled photo moves to the nearest tile before it")
    func focusMovesToEarlierTile() {
        let arrangement = PickArrangement(photoCount: 5, keeperPlaces: [1, 3], isDone: true)

        #expect(arrangement.tileIndex(nearestPlace: 4) == 1)
    }

    @Test("Focus before every tile moves to the first tile")
    func focusMovesToFirstTile() {
        let arrangement = PickArrangement(photoCount: 5, keeperPlaces: [1, 3], isDone: true)

        #expect(arrangement.tileIndex(nearestPlace: 0) == 0)
    }

    @Test("There is nowhere to focus when there are no tiles")
    func noFocusWithoutTiles() {
        let arrangement = PickArrangement(photoCount: 3, keeperPlaces: [], isDone: true)

        #expect(arrangement.tileIndex(nearestPlace: 1) == nil)
    }
}
