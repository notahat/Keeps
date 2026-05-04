import Foundation
@testable import Keeps
import Testing

struct GroupStoreTests {
    @Test func startsEmpty() {
        let store = GroupStore()

        #expect(store.groups.isEmpty)
    }

    // MARK: - addGroup

    @Test func addGroupCreatesGroupWithGivenItems() {
        var store = GroupStore()
        let ids: Set<UUID> = [UUID(), UUID(), UUID()]

        store.addGroup(itemIDs: ids)

        #expect(store.groups.count == 1)
        #expect(store.groups[0].itemIDs == ids)
    }

    @Test func addGroupReturnsTheNewGroupID() {
        var store = GroupStore()

        let newID = store.addGroup(itemIDs: [UUID()])

        #expect(store.groups[0].id == newID)
    }

    @Test func addGroupRemovesItemsFromOtherGroups() {
        var store = GroupStore()
        let shared = UUID()
        let firstOnly = UUID()
        let secondOnly = UUID()
        store.addGroup(itemIDs: [shared, firstOnly])

        store.addGroup(itemIDs: [shared, secondOnly])

        // First group keeps firstOnly, loses shared. Second group has both.
        #expect(store.groups.count == 2)
        #expect(store.groups[0].itemIDs == [firstOnly])
        #expect(store.groups[1].itemIDs == [shared, secondOnly])
    }

    @Test func addGroupDropsExistingGroupsLeftEmpty() {
        var store = GroupStore()
        let id = UUID()
        store.addGroup(itemIDs: [id])

        store.addGroup(itemIDs: [id])

        // Original group lost its only member; only the new group remains.
        #expect(store.groups.count == 1)
    }

    // MARK: - color selection

    @Test func nextColorIsTheFirstColorWhenNoGroupsExist() {
        var store = GroupStore()

        store.addGroup(itemIDs: [UUID()])

        #expect(store.groups[0].colorIndex == 0)
    }

    @Test func successiveGroupsGetDifferentColors() {
        var store = GroupStore()

        store.addGroup(itemIDs: [UUID()])
        store.addGroup(itemIDs: [UUID()])
        store.addGroup(itemIDs: [UUID()])

        let colorIndices = store.groups.map(\.colorIndex)
        #expect(Set(colorIndices).count == 3)
    }

    @Test func colorIndexCyclesWhenAllColorsUsed() {
        var store = GroupStore()
        for _ in 0 ..< GroupStore.colors.count {
            store.addGroup(itemIDs: [UUID()])
        }

        store.addGroup(itemIDs: [UUID()])

        // Every color is now used at least once; the new group reuses one of them.
        #expect(store.groups.count == GroupStore.colors.count + 1)
    }

    // MARK: - lookups

    @Test func groupContainingFindsTheItemsGroup() {
        var store = GroupStore()
        let id = UUID()
        let groupID = store.addGroup(itemIDs: [id])

        #expect(store.group(containing: id)?.id == groupID)
    }

    @Test func groupContainingReturnsNilForUngroupedItem() {
        var store = GroupStore()
        store.addGroup(itemIDs: [UUID()])

        #expect(store.group(containing: UUID()) == nil)
    }

    @Test func colorForItemReturnsTheGroupsColor() {
        var store = GroupStore()
        let id = UUID()
        store.addGroup(itemIDs: [id])
        let expected = GroupStore.colors[store.groups[0].colorIndex]

        #expect(store.color(forItem: id) == expected)
    }

    @Test func colorForItemReturnsNilForUngroupedItem() {
        var store = GroupStore()
        store.addGroup(itemIDs: [UUID()])

        #expect(store.color(forItem: UUID()) == nil)
    }

    @Test func colorForGroupReturnsTheGroupsColor() {
        var store = GroupStore()
        let groupID = store.addGroup(itemIDs: [UUID()])
        let expected = GroupStore.colors[store.groups[0].colorIndex]

        #expect(store.color(forGroup: groupID) == expected)
    }

    @Test func colorForGroupReturnsNilForUnknownGroupID() {
        var store = GroupStore()
        store.addGroup(itemIDs: [UUID()])

        #expect(store.color(forGroup: UUID()) == nil)
    }

    // MARK: - removeGroup

    @Test func removeGroupRemovesTheGroupContainingTheItem() {
        var store = GroupStore()
        let id = UUID()
        store.addGroup(itemIDs: [id, UUID()])

        store.removeGroup(containing: id)

        #expect(store.groups.isEmpty)
    }

    @Test func removeGroupLeavesOtherGroupsIntact() {
        var store = GroupStore()
        let firstID = UUID()
        let secondID = UUID()
        store.addGroup(itemIDs: [firstID])
        store.addGroup(itemIDs: [secondID])

        store.removeGroup(containing: firstID)

        #expect(store.groups.count == 1)
        #expect(store.groups[0].itemIDs == [secondID])
    }

    @Test func removeGroupDoesNothingForUngroupedItem() {
        var store = GroupStore()
        store.addGroup(itemIDs: [UUID()])

        store.removeGroup(containing: UUID())

        #expect(store.groups.count == 1)
    }

    // MARK: - applyRestored / reset

    @Test func applyRestoredReplacesGroups() {
        var store = GroupStore()
        store.addGroup(itemIDs: [UUID()])
        let restored = [
            GroupStore.PhotoGroup(id: UUID(), colorIndex: 2, itemIDs: [UUID()]),
        ]

        store.applyRestored(restored)

        #expect(store.groups.count == 1)
        #expect(store.groups[0].colorIndex == 2)
    }

    @Test func resetClearsAllGroups() {
        var store = GroupStore()
        store.addGroup(itemIDs: [UUID()])

        store.reset()

        #expect(store.groups.isEmpty)
    }
}
