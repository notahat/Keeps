import Foundation
@testable import Keeps
import Testing

struct PassTests {
    @Test func canStartNextPassIsFalseWithNoMarks() throws {
        let library = try makeLibrary(photoCount: 3)

        #expect(!library.canStartNextPass)
    }

    @Test func canStartNextPassIsTrueAfterPick() throws {
        let library = try makeLibrary(photoCount: 3)

        library.setMark(.pick, for: library.items[0])

        #expect(library.canStartNextPass)
    }

    @Test func canStartNextPassIsTrueAfterReject() throws {
        let library = try makeLibrary(photoCount: 3)

        library.setMark(.reject, for: library.items[0])

        #expect(library.canStartNextPass)
    }

    @Test func startNextPassCreatesNewPass() throws {
        let library = try makeLibrary(photoCount: 3)
        library.setMark(.pick, for: library.items[0])

        library.startNextPass()

        #expect(library.passes.count == 2)
        #expect(library.currentPassIndex == 1)
    }

    @Test func photosMarkedInEarlierPassAreHiddenFromLaterPass() throws {
        let library = try makeLibrary(photoCount: 3)
        library.setMark(.pick, for: library.items[0])
        library.setMark(.reject, for: library.items[1])

        library.startNextPass()

        #expect(library.filteredItems.count == 1)
        #expect(library.filteredItems[0].id == library.items[2].id)
    }

    @Test func selectPassSwitchesPassAndResetsFilter() throws {
        let library = try makeLibrary(photoCount: 3)
        library.setMark(.pick, for: library.items[0])
        library.startNextPass()

        library.selectPass(0)

        #expect(library.currentPassIndex == 0)
        #expect(library.filterMode == .all)
        #expect(library.filteredItems.count == 3)
    }

    @Test func statsReturnsCorrectCounts() throws {
        let library = try makeLibrary(photoCount: 5)
        library.setMark(.pick, for: library.items[0])
        library.setMark(.pick, for: library.items[1])
        library.setMark(.reject, for: library.items[2])

        let passStats = library.stats(for: 0)

        #expect(passStats.total == 5)
        #expect(passStats.picks == 2)
        #expect(passStats.rejects == 1)
    }

    @Test func statsExcludesPhotosMarkedInEarlierPasses() throws {
        let library = try makeLibrary(photoCount: 5)
        library.setMark(.pick, for: library.items[0])
        library.setMark(.reject, for: library.items[1])
        library.startNextPass()
        library.setMark(.pick, for: library.items[2])

        let passStats = library.stats(for: 1)

        #expect(passStats.total == 3)
        #expect(passStats.picks == 1)
        #expect(passStats.rejects == 0)
    }
}
