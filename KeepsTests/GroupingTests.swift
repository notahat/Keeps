import Foundation
@testable import Keeps
import Testing

struct GroupingTests {
    @Test func createGroupFromSelectionCreatesGroupWithCorrectItems() throws {
        let library = try makeLibrary(photoCount: 5)

        library.selectItem(at: 1)
        library.extendSelection(to: 3)
        library.createGroupFromSelection()

        #expect(library.groups.count == 1)
        let group = try #require(library.groups.first)
        #expect(group.itemIDs == Set(library.items[1 ... 3].map(\.id)))
    }

    @Test func createGroupFromSelectionIgnoresSingleItemSelection() throws {
        let library = try makeLibrary(photoCount: 5)

        library.selectItem(at: 2)
        library.createGroupFromSelection()

        #expect(library.groups.isEmpty)
    }

    @Test func createGroupFromSelectionIgnoresEmptySelection() throws {
        let library = try makeLibrary(photoCount: 5)

        library.createGroupFromSelection()

        #expect(library.groups.isEmpty)
    }

    @Test func groupColorReturnsColorForGroupedPhoto() throws {
        let library = try makeLibrary(photoCount: 5)

        library.selectItem(at: 1)
        library.extendSelection(to: 2)
        library.createGroupFromSelection()

        #expect(library.groupColor(for: library.items[1].id) != nil)
        #expect(library.groupColor(for: library.items[2].id) != nil)
    }

    @Test func groupColorReturnsSameColorForItemsInSameGroup() throws {
        let library = try makeLibrary(photoCount: 5)

        library.selectItem(at: 1)
        library.extendSelection(to: 3)
        library.createGroupFromSelection()

        let color1 = library.groupColor(for: library.items[1].id)
        let color2 = library.groupColor(for: library.items[2].id)
        let color3 = library.groupColor(for: library.items[3].id)
        #expect(color1 == color2)
        #expect(color2 == color3)
    }

    @Test func groupColorReturnsNilForUngroupedPhoto() throws {
        let library = try makeLibrary(photoCount: 5)

        library.selectItem(at: 1)
        library.extendSelection(to: 2)
        library.createGroupFromSelection()

        #expect(library.groupColor(for: library.items[0].id) == nil)
        #expect(library.groupColor(for: library.items[4].id) == nil)
    }

    @Test func createGroupAssignsDifferentColorsToSuccessiveGroups() throws {
        let library = try makeLibrary(photoCount: 6)

        library.selectItem(at: 0)
        library.extendSelection(to: 1)
        library.createGroupFromSelection()

        library.selectItem(at: 2)
        library.extendSelection(to: 3)
        library.createGroupFromSelection()

        let color1 = library.groupColor(for: library.items[0].id)
        let color2 = library.groupColor(for: library.items[2].id)
        #expect(color1 != color2)
    }

    @Test func createGroupMovesItemsFromOldGroupToNewGroup() throws {
        let library = try makeLibrary(photoCount: 6)

        library.selectItem(at: 0)
        library.extendSelection(to: 2)
        library.createGroupFromSelection()

        library.selectItem(at: 1)
        library.extendSelection(to: 3)
        library.createGroupFromSelection()

        #expect(library.groups.count == 2)
        let itemID1 = library.items[1].id
        let itemID2 = library.items[2].id
        let firstGroup = try #require(library.groups.first)
        #expect(!firstGroup.itemIDs.contains(itemID1))
        #expect(!firstGroup.itemIDs.contains(itemID2))
    }

    @Test func closeClearsGroups() throws {
        let library = try makeLibrary(photoCount: 5)

        library.selectItem(at: 1)
        library.extendSelection(to: 3)
        library.createGroupFromSelection()
        library.close()

        #expect(library.groups.isEmpty)
    }
}
