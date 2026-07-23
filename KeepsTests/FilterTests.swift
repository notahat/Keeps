import Foundation
@testable import Keeps
import Testing

@MainActor
struct FilterTests {
    @Test func filterAllShowsAllCurrentPassPhotos() {
        let library = makeLibrary(photoCount: 3)
        library.setMark(.pick, for: library.items[0])

        library.applyFilter(.all)

        #expect(library.filteredItems.count == 3)
    }

    @Test func filterPickedShowsOnlyPicks() {
        let library = makeLibrary(photoCount: 3)
        library.setMark(.pick, for: library.items[0])
        library.setMark(.reject, for: library.items[1])

        library.applyFilter(.picked)

        #expect(library.filteredItems.count == 1)
        #expect(library.filteredItems[0].id == library.items[0].id)
    }

    @Test func filterRejectedShowsOnlyRejects() {
        let library = makeLibrary(photoCount: 3)
        library.setMark(.pick, for: library.items[0])
        library.setMark(.reject, for: library.items[1])

        library.applyFilter(.rejected)

        #expect(library.filteredItems.count == 1)
        #expect(library.filteredItems[0].id == library.items[1].id)
    }

    @Test func filterUnmarkedShowsOnlyUnmarkedPhotos() {
        let library = makeLibrary(photoCount: 3)
        library.setMark(.pick, for: library.items[0])
        library.setMark(.reject, for: library.items[1])

        library.applyFilter(.unmarked)

        #expect(library.filteredItems.count == 1)
        #expect(library.filteredItems[0].id == library.items[2].id)
    }
}
