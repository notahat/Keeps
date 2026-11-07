@testable import Keeps
import Testing

struct PileTests {
    @Test("Keepers go on top of the pile, each part in its original order")
    func keepersOnTop() {
        let photos = makePhotos(count: 10)

        let pile = Pile(group: 2 ..< 7, folderPhotos: photos, keepers: [3, 5])

        #expect(pile.photos.map(\.id) == [3, 5, 2, 4, 6].map { photos[$0].id })
    }

    @Test("A pile with no keepers keeps its photos in order")
    func noKeepersKeepsOrder() {
        let photos = makePhotos(count: 10)

        let pile = Pile(group: 2 ..< 5, folderPhotos: photos, keepers: [])

        #expect(pile.photos.map(\.id) == [2, 3, 4].map { photos[$0].id })
    }

    @Test("Keepers outside the group are left out")
    func ignoresKeepersOutsideGroup() {
        let photos = makePhotos(count: 10)

        let pile = Pile(group: 2 ..< 5, folderPhotos: photos, keepers: [0, 3, 8])

        #expect(pile.photos.map(\.id) == [3, 2, 4].map { photos[$0].id })
    }
}
