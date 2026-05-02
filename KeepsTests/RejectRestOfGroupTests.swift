import Foundation
@testable import Keeps
import Testing

struct RejectRestOfGroupTests {
    @Test func rejectRestOfGroupRejectsUnmarkedGroupMembers() throws {
        let library = try makeLibrary(photoCount: 5)

        library.selectItem(at: 1)
        library.extendSelection(to: 3)
        library.createGroupFromSelection()
        library.selectItem(at: 2)
        library.rejectRestOfGroup()

        #expect(library.mark(for: library.items[1].id) == .reject)
        #expect(library.mark(for: library.items[2].id) == .reject)
        #expect(library.mark(for: library.items[3].id) == .reject)
    }

    @Test func rejectRestOfGroupLeavesPicks() throws {
        let library = try makeLibrary(photoCount: 5)

        library.selectItem(at: 1)
        library.extendSelection(to: 3)
        library.createGroupFromSelection()
        library.setMark(.pick, for: library.items[2])
        library.selectItem(at: 1)
        library.rejectRestOfGroup()

        #expect(library.mark(for: library.items[2].id) == .pick)
        #expect(library.mark(for: library.items[1].id) == .reject)
        #expect(library.mark(for: library.items[3].id) == .reject)
    }

    @Test func rejectRestOfGroupIgnoresItemsNotInCurrentPass() throws {
        let library = try makeLibrary(photoCount: 5)

        library.selectItem(at: 0)
        library.extendSelection(to: 2)
        library.createGroupFromSelection()
        // Mark items[0] in pass 0, making it invisible in pass 1.
        library.setMark(.pick, for: library.items[0])
        library.startNextPass()

        library.selectItem(at: 0)
        library.rejectRestOfGroup()

        // items[0] was marked in a previous pass — its pass-0 pick should be unchanged.
        #expect(library.cumulativeMark(for: library.items[0].id) == .pick)
    }

    @Test func rejectRestOfGroupDoesNothingWhenNotGrouped() throws {
        let library = try makeLibrary(photoCount: 5)

        library.selectItem(at: 2)
        library.rejectRestOfGroup()

        for item in library.items {
            #expect(library.mark(for: item.id) == nil)
        }
    }

    @Test func rejectRestOfGroupDoesNotAffectPhotosOutsideGroup() throws {
        let library = try makeLibrary(photoCount: 5)

        library.selectItem(at: 1)
        library.extendSelection(to: 2)
        library.createGroupFromSelection()
        library.selectItem(at: 1)
        library.rejectRestOfGroup()

        #expect(library.mark(for: library.items[0].id) == nil)
        #expect(library.mark(for: library.items[3].id) == nil)
        #expect(library.mark(for: library.items[4].id) == nil)
    }
}
