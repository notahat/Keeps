import Foundation
@testable import Keeps
import Testing

@MainActor
struct FilterTests {
    @Test func filterAllShowsAllCurrentPassPhotos() {
        let workflow = makeWorkflow(photoCount: 3)
        workflow.setMark(.pick, for: workflow.items[0])

        workflow.applyFilter(.all)

        #expect(workflow.filteredItems.count == 3)
    }

    @Test func filterPickedShowsOnlyPicks() {
        let workflow = makeWorkflow(photoCount: 3)
        workflow.setMark(.pick, for: workflow.items[0])
        workflow.setMark(.reject, for: workflow.items[1])

        workflow.applyFilter(.picked)

        #expect(workflow.filteredItems.count == 1)
        #expect(workflow.filteredItems[0].id == workflow.items[0].id)
    }

    @Test func filterRejectedShowsOnlyRejects() {
        let workflow = makeWorkflow(photoCount: 3)
        workflow.setMark(.pick, for: workflow.items[0])
        workflow.setMark(.reject, for: workflow.items[1])

        workflow.applyFilter(.rejected)

        #expect(workflow.filteredItems.count == 1)
        #expect(workflow.filteredItems[0].id == workflow.items[1].id)
    }

    @Test func filterUnmarkedShowsOnlyUnmarkedPhotos() {
        let workflow = makeWorkflow(photoCount: 3)
        workflow.setMark(.pick, for: workflow.items[0])
        workflow.setMark(.reject, for: workflow.items[1])

        workflow.applyFilter(.unmarked)

        #expect(workflow.filteredItems.count == 1)
        #expect(workflow.filteredItems[0].id == workflow.items[2].id)
    }
}
