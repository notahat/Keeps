@testable import Keeps
import Testing

struct PileTests {
    @Test("Keepers go on top of the pile, each part in its original order")
    func keepersOnTop() {
        let items = makePhotoItems(count: 10)

        let pile = Pile(group: 2 ..< 7, items: items, keepers: [3, 5], isDone: true)

        #expect(pile.photos.map(\.id) == [3, 5, 2, 4, 6].map { items[$0].id })
    }

    @Test("A pile with no keepers keeps its photos in order")
    func noKeepersKeepsOrder() {
        let items = makePhotoItems(count: 10)

        let pile = Pile(group: 2 ..< 5, items: items, keepers: [], isDone: false)

        #expect(pile.photos.map(\.id) == [2, 3, 4].map { items[$0].id })
    }

    @Test("Only keepers in the group are counted")
    func countsKeepersInGroup() {
        let items = makePhotoItems(count: 10)

        let pile = Pile(group: 2 ..< 5, items: items, keepers: [0, 3, 8], isDone: true)

        #expect(pile.keeperCount == 1)
    }

    @Test("In a done pile, the photos that aren't keepers are faded")
    func doneFadesNonKeepers() {
        let items = makePhotoItems(count: 10)

        let pile = Pile(group: 2 ..< 7, items: items, keepers: [3, 5], isDone: true)

        #expect((0 ..< 5).map(pile.isFaded(layer:)) == [false, false, true, true, true])
    }

    @Test("In a done pile with no keepers, every photo is faded")
    func doneWithNoKeepersFadesAll() {
        let items = makePhotoItems(count: 10)

        let pile = Pile(group: 2 ..< 5, items: items, keepers: [], isDone: true)

        #expect((0 ..< 3).allSatisfy(pile.isFaded(layer:)))
    }

    @Test("A pile that isn't done fades nothing, even with no keepers")
    func notDoneFadesNothing() {
        let items = makePhotoItems(count: 10)

        let pile = Pile(group: 2 ..< 5, items: items, keepers: [], isDone: false)

        #expect(!(0 ..< 3).contains(where: pile.isFaded(layer:)))
    }
}
