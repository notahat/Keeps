import Foundation
@testable import Keeps
import Testing

struct SimpleCullStateTests {
    @Test func marksRoundTripThroughSnapshotAndRestore() {
        let workflow = makeWorkflow(photoCount: 3)
        workflow.setMark(.pick, for: workflow.items[0])
        workflow.setMark(.reject, for: workflow.items[1])

        let state = workflow.snapshotState()
        let restoredWorkflow = SimpleCullWorkflow(items: workflow.items)
        restoredWorkflow.applyRestored(state: state)

        #expect(restoredWorkflow.mark(for: workflow.items[0].id) == .pick)
        #expect(restoredWorkflow.mark(for: workflow.items[1].id) == .reject)
        #expect(restoredWorkflow.mark(for: workflow.items[2].id) == nil)
    }

    @Test func applyRestoredDropsStemsMissingFromTheFolder() {
        let workflow = makeWorkflow(photoCount: 1)
        let state = SimpleCullState(
            picks: [workflow.items[0].stem, "IMG_9999"],
            rejects: ["IMG_8888"]
        )

        workflow.applyRestored(state: state)

        #expect(workflow.mark(for: workflow.items[0].id) == .pick)
        #expect(workflow.snapshotState() == SimpleCullState(
            picks: [workflow.items[0].stem],
            rejects: []
        ))
    }

    @Test func applyRestoredResetsTheSelectionToTheFirstPhoto() {
        let workflow = makeWorkflow(photoCount: 3)
        workflow.selectItem(at: 2)

        workflow.applyRestored(state: SimpleCullState(picks: [], rejects: []))

        #expect(workflow.selectedItemID == workflow.items[0].id)
    }
}
