import Foundation
@testable import Keeps
import Testing

struct PassStoreTests {
    // MARK: - Setup

    @Test func startsEmpty() {
        let store = PassStore()

        #expect(store.passes.isEmpty)
        #expect(store.currentPassIndex == 0)
        #expect(store.currentPass == nil)
    }

    @Test func initializeFreshCreatesOneEmptyPass() {
        var store = PassStore()

        store.initializeFresh()

        #expect(store.passes.count == 1)
        #expect(store.currentPassIndex == 0)
        #expect(store.passes[0].picks.isEmpty)
        #expect(store.passes[0].rejects.isEmpty)
    }

    // MARK: - canStartNextPass

    @Test func canStartNextPassIsFalseBeforeAnyMarks() {
        var store = PassStore()
        store.initializeFresh()

        #expect(!store.canStartNextPass)
    }

    @Test func canStartNextPassIsTrueAfterPick() {
        var store = PassStore()
        store.initializeFresh()
        store.setMark(.pick, for: UUID())

        #expect(store.canStartNextPass)
    }

    @Test func canStartNextPassIsTrueAfterReject() {
        var store = PassStore()
        store.initializeFresh()
        store.setMark(.reject, for: UUID())

        #expect(store.canStartNextPass)
    }

    // MARK: - setMark

    @Test func setMarkPickRecordsAsPick() {
        var store = PassStore()
        store.initializeFresh()
        let id = UUID()

        store.setMark(.pick, for: id)

        #expect(store.mark(for: id) == .pick)
    }

    @Test func setMarkRejectRecordsAsReject() {
        var store = PassStore()
        store.initializeFresh()
        let id = UUID()

        store.setMark(.reject, for: id)

        #expect(store.mark(for: id) == .reject)
    }

    @Test func setMarkNilUnmarks() {
        var store = PassStore()
        store.initializeFresh()
        let id = UUID()
        store.setMark(.pick, for: id)

        store.setMark(nil, for: id)

        #expect(store.mark(for: id) == nil)
    }

    @Test func setMarkPickClearsExistingReject() {
        var store = PassStore()
        store.initializeFresh()
        let id = UUID()
        store.setMark(.reject, for: id)

        store.setMark(.pick, for: id)

        #expect(store.mark(for: id) == .pick)
        #expect(!store.passes[0].rejects.contains(id))
    }

    // MARK: - startNextPass / selectPass

    @Test func startNextPassAppendsAndSelectsTheNewPass() {
        var store = PassStore()
        store.initializeFresh()
        store.setMark(.pick, for: UUID())

        store.startNextPass()

        #expect(store.passes.count == 2)
        #expect(store.currentPassIndex == 1)
    }

    @Test func selectPassSwitchesIndex() {
        var store = PassStore()
        store.initializeFresh()
        store.startNextPass()

        store.selectPass(0)

        #expect(store.currentPassIndex == 0)
    }

    // MARK: - cumulativeMark

    @Test func cumulativeMarkReturnsNilForUnmarkedPhoto() {
        var store = PassStore()
        store.initializeFresh()

        #expect(store.cumulativeMark(for: UUID()) == nil)
    }

    @Test func cumulativeMarkReturnsCurrentPassMark() {
        var store = PassStore()
        store.initializeFresh()
        let id = UUID()
        store.setMark(.pick, for: id)

        #expect(store.cumulativeMark(for: id) == .pick)
    }

    @Test func cumulativeMarkPrefersLatestPassWhenMarkedInMultiplePasses() {
        var store = PassStore()
        store.initializeFresh()
        let id = UUID()
        store.setMark(.reject, for: id)
        store.startNextPass()
        store.setMark(.pick, for: id)

        #expect(store.cumulativeMark(for: id) == .pick)
    }

    // MARK: - currentPassPhotoIDs

    @Test func currentPassPhotoIDsReturnsAllItemsInFirstPass() {
        var store = PassStore()
        store.initializeFresh()
        let items = makePhotoItems(count: 3)

        let visible = store.currentPassPhotoIDs(items: items)

        #expect(visible == Set(items.map(\.id)))
    }

    @Test func currentPassPhotoIDsExcludesItemsMarkedInEarlierPasses() {
        var store = PassStore()
        store.initializeFresh()
        let items = makePhotoItems(count: 3)
        store.setMark(.pick, for: items[0].id)
        store.setMark(.reject, for: items[1].id)
        store.startNextPass()

        let visible = store.currentPassPhotoIDs(items: items)

        #expect(visible == [items[2].id])
    }

    // MARK: - sortPlan

    @Test func sortPlanGroupsItemsByCumulativeMark() {
        var store = PassStore()
        store.initializeFresh()
        let items = makePhotoItems(count: 3)
        store.setMark(.pick, for: items[0].id)
        store.setMark(.reject, for: items[1].id)

        let plan = store.sortPlan(items: items)

        #expect(plan[.pick]?.map(\.id) == [items[0].id])
        #expect(plan[.reject]?.map(\.id) == [items[1].id])
        #expect(plan[nil]?.map(\.id) == [items[2].id])
    }

    // MARK: - stats

    @Test func statsReportsTotalPicksAndRejectsForCurrentPass() {
        var store = PassStore()
        store.initializeFresh()
        let items = makePhotoItems(count: 5)
        store.setMark(.pick, for: items[0].id)
        store.setMark(.pick, for: items[1].id)
        store.setMark(.reject, for: items[2].id)

        let stats = store.stats(for: 0, items: items)

        #expect(stats.total == 5)
        #expect(stats.picks == 2)
        #expect(stats.rejects == 1)
    }

    @Test func statsTotalExcludesItemsMarkedInEarlierPasses() {
        var store = PassStore()
        store.initializeFresh()
        let items = makePhotoItems(count: 5)
        store.setMark(.pick, for: items[0].id)
        store.setMark(.reject, for: items[1].id)
        store.startNextPass()
        store.setMark(.pick, for: items[2].id)

        let stats = store.stats(for: 1, items: items)

        #expect(stats.total == 3)
        #expect(stats.picks == 1)
        #expect(stats.rejects == 0)
    }

    // MARK: - applyRestored / reset

    @Test func applyRestoredReplacesPasses() {
        var store = PassStore()
        store.initializeFresh()
        let id = UUID()
        let restored = [
            PassStore.Pass(picks: [id], rejects: []),
            PassStore.Pass(picks: [], rejects: [id]),
        ]

        store.applyRestored(passes: restored, currentPassIndex: 1)

        #expect(store.passes.count == 2)
        #expect(store.currentPassIndex == 1)
        #expect(store.mark(for: id) == .reject)
    }

    @Test func resetClearsAllState() {
        var store = PassStore()
        store.initializeFresh()
        store.setMark(.pick, for: UUID())
        store.startNextPass()

        store.reset()

        #expect(store.passes.isEmpty)
        #expect(store.currentPassIndex == 0)
    }
}
