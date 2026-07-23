import Foundation
@testable import Keeps
import Testing

struct SimpleCullStateTests {
    @Test func marksRoundTripThroughSnapshotAndRestore() {
        let library = makeLibrary(photoCount: 3)
        library.setMark(.pick, for: library.items[0])
        library.setMark(.reject, for: library.items[1])

        let state = library.snapshotState()
        let restoredLibrary = FolderLibrary(items: library.items)
        restoredLibrary.applyRestored(state: state)

        #expect(restoredLibrary.mark(for: library.items[0].id) == .pick)
        #expect(restoredLibrary.mark(for: library.items[1].id) == .reject)
        #expect(restoredLibrary.mark(for: library.items[2].id) == nil)
    }

    @Test func applyRestoredDropsStemsMissingFromTheFolder() {
        let library = makeLibrary(photoCount: 1)
        let state = SimpleCullState(
            picks: [library.items[0].stem, "IMG_9999"],
            rejects: ["IMG_8888"]
        )

        library.applyRestored(state: state)

        #expect(library.mark(for: library.items[0].id) == .pick)
        #expect(library.snapshotState() == SimpleCullState(
            picks: [library.items[0].stem],
            rejects: []
        ))
    }

    @Test func applyRestoredResetsTheSelectionToTheFirstPhoto() {
        let library = makeLibrary(photoCount: 3)
        library.selectItem(at: 2)

        library.applyRestored(state: SimpleCullState(picks: [], rejects: []))

        #expect(library.selectedItemID == library.items[0].id)
    }
}
