import Foundation
@testable import Keeps
import Testing

struct MarkingTests {
    @Test func unmarkedPhotoReturnsNilMark() throws {
        let library = try makeLibrary(photoCount: 3)

        #expect(library.mark(for: library.items[0].id) == nil)
    }

    @Test func setMarkPickMarksPhotoAsPick() throws {
        let library = try makeLibrary(photoCount: 3)

        library.setMark(.pick, for: library.items[0])

        #expect(library.mark(for: library.items[0].id) == .pick)
    }

    @Test func setMarkRejectMarksPhotoAsReject() throws {
        let library = try makeLibrary(photoCount: 3)

        library.setMark(.reject, for: library.items[0])

        #expect(library.mark(for: library.items[0].id) == .reject)
    }

    @Test func setMarkNilUnmarksPhoto() throws {
        let library = try makeLibrary(photoCount: 3)

        library.setMark(.pick, for: library.items[0])
        library.setMark(nil, for: library.items[0])

        #expect(library.mark(for: library.items[0].id) == nil)
    }

    @Test func setMarkPickClearsExistingReject() throws {
        let library = try makeLibrary(photoCount: 3)

        library.setMark(.reject, for: library.items[0])
        library.setMark(.pick, for: library.items[0])

        #expect(library.mark(for: library.items[0].id) == .pick)
    }

    @Test func setMarkRejectClearsExistingPick() throws {
        let library = try makeLibrary(photoCount: 3)

        library.setMark(.pick, for: library.items[0])
        library.setMark(.reject, for: library.items[0])

        #expect(library.mark(for: library.items[0].id) == .reject)
    }

    @Test func applyMarkAndAdvanceMovesToNextItem() throws {
        let library = try makeLibrary(photoCount: 3)
        library.selectedIndex = 0

        library.applyMarkAndAdvance(.pick)

        #expect(library.mark(for: library.items[0].id) == .pick)
        #expect(library.selectedIndex == 1)
    }

    @Test func applyMarkAndAdvanceStaysAtEndOfList() throws {
        let library = try makeLibrary(photoCount: 3)
        library.selectedIndex = 2

        library.applyMarkAndAdvance(.reject)

        #expect(library.mark(for: library.items[2].id) == .reject)
        #expect(library.selectedIndex == 2)
    }

    @Test func applyMarkAndAdvanceDoesNothingWithNoSelection() throws {
        let library = try makeLibrary(photoCount: 3)
        library.selectedIndex = nil

        library.applyMarkAndAdvance(.pick)

        for item in library.items {
            #expect(library.mark(for: item.id) == nil)
        }
    }

    @Test func applyMarkAndAdvanceSetsLastMarkEvent() throws {
        let library = try makeLibrary(photoCount: 3)
        library.selectedIndex = 0

        library.applyMarkAndAdvance(.pick)

        #expect(library.lastMarkEvent != nil)
        #expect(library.lastMarkEvent?.mark == .pick)
    }

    @Test func eachApplyMarkAndAdvanceProducesDistinctEvent() throws {
        let library = try makeLibrary(photoCount: 3)
        library.selectedIndex = 0

        library.applyMarkAndAdvance(.pick)
        let firstEvent = library.lastMarkEvent

        library.applyMarkAndAdvance(.pick)
        let secondEvent = library.lastMarkEvent

        #expect(firstEvent != secondEvent)
    }
}
