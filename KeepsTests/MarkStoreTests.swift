import Foundation
@testable import Keeps
import Testing

struct MarkStoreTests {
    @Test func returnsNilForAnUnmarkedPhoto() {
        let store = MarkStore()

        #expect(store.mark(for: UUID()) == nil)
    }

    @Test func setMarkPickMarksThePhoto() {
        var store = MarkStore()
        let id = UUID()

        store.setMark(.pick, for: id)

        #expect(store.mark(for: id) == .pick)
    }

    @Test func setMarkRejectReplacesAnExistingPick() {
        var store = MarkStore()
        let id = UUID()

        store.setMark(.pick, for: id)
        store.setMark(.reject, for: id)

        #expect(store.mark(for: id) == .reject)
    }

    @Test func setMarkNilClearsAnExistingMark() {
        var store = MarkStore()
        let id = UUID()

        store.setMark(.pick, for: id)
        store.setMark(nil, for: id)

        #expect(store.mark(for: id) == nil)
    }

    @Test func applyRestoredReplacesAllMarks() {
        var store = MarkStore()
        let oldID = UUID()
        let newID = UUID()
        store.setMark(.pick, for: oldID)

        store.applyRestored(marks: [newID: .reject])

        #expect(store.mark(for: oldID) == nil)
        #expect(store.mark(for: newID) == .reject)
    }
}
