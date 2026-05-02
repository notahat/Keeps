import Foundation
@testable import Keeps
import Testing

struct FilterTests {
    @Test func filterAllShowsAllCurrentPassPhotos() throws {
        let library = try makeLibrary(photoCount: 3)
        library.setMark(.pick, for: library.items[0])

        library.applyFilter(.all)

        #expect(library.filteredItems.count == 3)
    }

    @Test func filterPickedShowsOnlyPicks() throws {
        let library = try makeLibrary(photoCount: 3)
        library.setMark(.pick, for: library.items[0])
        library.setMark(.reject, for: library.items[1])

        library.applyFilter(.picked)

        #expect(library.filteredItems.count == 1)
        #expect(library.filteredItems[0].id == library.items[0].id)
    }

    @Test func filterRejectedShowsOnlyRejects() throws {
        let library = try makeLibrary(photoCount: 3)
        library.setMark(.pick, for: library.items[0])
        library.setMark(.reject, for: library.items[1])

        library.applyFilter(.rejected)

        #expect(library.filteredItems.count == 1)
        #expect(library.filteredItems[0].id == library.items[1].id)
    }

    @Test func filterUnmarkedShowsOnlyUnmarkedPhotos() throws {
        let library = try makeLibrary(photoCount: 3)
        library.setMark(.pick, for: library.items[0])
        library.setMark(.reject, for: library.items[1])

        library.applyFilter(.unmarked)

        #expect(library.filteredItems.count == 1)
        #expect(library.filteredItems[0].id == library.items[2].id)
    }

    @Test func filterAllInLaterPassExcludesEarlierPassMarks() throws {
        let library = try makeLibrary(photoCount: 5)
        library.setMark(.pick, for: library.items[0])
        library.setMark(.reject, for: library.items[1])
        library.startNextPass()

        library.applyFilter(.all)

        #expect(library.filteredItems.count == 3)
        let filteredIDs = Set(library.filteredItems.map(\.id))
        #expect(!filteredIDs.contains(library.items[0].id))
        #expect(!filteredIDs.contains(library.items[1].id))
    }

    @Test func filterUnmarkedInLaterPassExcludesBothPassMarks() throws {
        let library = try makeLibrary(photoCount: 5)
        library.setMark(.pick, for: library.items[0])
        library.setMark(.reject, for: library.items[1])
        library.startNextPass()
        library.setMark(.pick, for: library.items[2])

        library.applyFilter(.unmarked)

        #expect(library.filteredItems.count == 2)
        let filteredIDs = Set(library.filteredItems.map(\.id))
        #expect(filteredIDs.contains(library.items[3].id))
        #expect(filteredIDs.contains(library.items[4].id))
    }

    @Test func filterGroupShowsOnlyGroupMembersInCurrentPass() throws {
        let library = try makeLibrary(photoCount: 5)
        library.selectItem(at: 0)
        library.extendSelection(to: 2)
        library.createGroupFromSelection()
        library.selectItem(at: 1)

        library.focusSelectedItemGroup()

        let filteredIDs = Set(library.filteredItems.map(\.id))
        #expect(filteredIDs.contains(library.items[0].id))
        #expect(filteredIDs.contains(library.items[1].id))
        #expect(filteredIDs.contains(library.items[2].id))
        #expect(!filteredIDs.contains(library.items[3].id))
        #expect(!filteredIDs.contains(library.items[4].id))
    }

    @Test func filterGroupExcludesGroupMembersHiddenByEarlierPass() throws {
        let library = try makeLibrary(photoCount: 5)
        library.selectItem(at: 0)
        library.extendSelection(to: 2)
        library.createGroupFromSelection()
        library.setMark(.pick, for: library.items[0])
        library.startNextPass()
        library.selectItem(at: 0)

        library.focusSelectedItemGroup()

        let filteredIDs = Set(library.filteredItems.map(\.id))
        #expect(!filteredIDs.contains(library.items[0].id))
        #expect(filteredIDs.contains(library.items[1].id))
        #expect(filteredIDs.contains(library.items[2].id))
    }

    @Test func filterGroupPreservesSelectedItem() throws {
        let library = try makeLibrary(photoCount: 5)
        library.selectItem(at: 0)
        library.extendSelection(to: 2)
        library.createGroupFromSelection()
        library.selectItem(at: 1)
        let selectedID = library.selectedItemID

        library.focusSelectedItemGroup()

        #expect(library.selectedItemID == selectedID)
    }

    @Test func ungroupSelectedItemResetsGroupFocusFilter() throws {
        let library = try makeLibrary(photoCount: 5)
        library.selectItem(at: 0)
        library.extendSelection(to: 2)
        library.createGroupFromSelection()
        library.selectItem(at: 1)
        library.focusSelectedItemGroup()

        library.selectItem(at: 0)
        library.ungroupSelectedItem()

        #expect(library.filterMode == .all)
        #expect(library.filteredItems.count == 5)
    }

    @Test func startNextPassResetsGroupFocusFilter() throws {
        let library = try makeLibrary(photoCount: 5)
        library.selectItem(at: 0)
        library.extendSelection(to: 2)
        library.createGroupFromSelection()
        library.selectItem(at: 1)
        library.focusSelectedItemGroup()
        library.setMark(.pick, for: library.items[0])

        library.startNextPass()

        #expect(library.filterMode == .all)
    }

    @Test func selectPassResetsGroupFocusFilter() throws {
        let library = try makeLibrary(photoCount: 5)
        library.selectItem(at: 0)
        library.extendSelection(to: 2)
        library.createGroupFromSelection()
        library.setMark(.pick, for: library.items[0])
        library.startNextPass()
        library.selectItem(at: 0)
        library.focusSelectedItemGroup()

        library.selectPass(0)

        #expect(library.filterMode == .all)
    }
}
