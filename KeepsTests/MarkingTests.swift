import Foundation
@testable import Keeps
import Testing

struct MarkingTests {
    @Test func unmarkedPhotoReturnsNilMark() throws {
        let workflow = makeWorkflow(photoCount: 3)

        #expect(workflow.mark(for: workflow.items[0].id) == nil)
    }

    @Test func setMarkPickMarksPhotoAsPick() throws {
        let workflow = makeWorkflow(photoCount: 3)

        workflow.setMark(.pick, for: workflow.items[0])

        #expect(workflow.mark(for: workflow.items[0].id) == .pick)
    }

    @Test func setMarkRejectMarksPhotoAsReject() throws {
        let workflow = makeWorkflow(photoCount: 3)

        workflow.setMark(.reject, for: workflow.items[0])

        #expect(workflow.mark(for: workflow.items[0].id) == .reject)
    }

    @Test func setMarkNilUnmarksPhoto() throws {
        let workflow = makeWorkflow(photoCount: 3)

        workflow.setMark(.pick, for: workflow.items[0])
        workflow.setMark(nil, for: workflow.items[0])

        #expect(workflow.mark(for: workflow.items[0].id) == nil)
    }

    @Test func setMarkPickClearsExistingReject() throws {
        let workflow = makeWorkflow(photoCount: 3)

        workflow.setMark(.reject, for: workflow.items[0])
        workflow.setMark(.pick, for: workflow.items[0])

        #expect(workflow.mark(for: workflow.items[0].id) == .pick)
    }

    @Test func setMarkRejectClearsExistingPick() throws {
        let workflow = makeWorkflow(photoCount: 3)

        workflow.setMark(.pick, for: workflow.items[0])
        workflow.setMark(.reject, for: workflow.items[0])

        #expect(workflow.mark(for: workflow.items[0].id) == .reject)
    }

    @Test func applyMarkAndAdvanceMovesToNextItem() throws {
        let workflow = makeWorkflow(photoCount: 3)
        workflow.selectedIndex = 0

        workflow.applyMarkAndAdvance(.pick)

        #expect(workflow.mark(for: workflow.items[0].id) == .pick)
        #expect(workflow.selectedIndex == 1)
    }

    @Test func applyMarkAndAdvanceStaysAtEndOfList() throws {
        let workflow = makeWorkflow(photoCount: 3)
        workflow.selectedIndex = 2

        workflow.applyMarkAndAdvance(.reject)

        #expect(workflow.mark(for: workflow.items[2].id) == .reject)
        #expect(workflow.selectedIndex == 2)
    }

    @Test func applyMarkAndAdvanceDoesNothingWithNoSelection() throws {
        let workflow = makeWorkflow(photoCount: 3)
        workflow.selectedIndex = nil

        workflow.applyMarkAndAdvance(.pick)

        for item in workflow.items {
            #expect(workflow.mark(for: item.id) == nil)
        }
    }

    @Test func applyMarkAndAdvanceSetsLastMarkEvent() throws {
        let workflow = makeWorkflow(photoCount: 3)
        workflow.selectedIndex = 0

        workflow.applyMarkAndAdvance(.pick)

        #expect(workflow.lastMarkEvent != nil)
        #expect(workflow.lastMarkEvent?.mark == .pick)
    }

    @Test func eachApplyMarkAndAdvanceProducesDistinctEvent() throws {
        let workflow = makeWorkflow(photoCount: 3)
        workflow.selectedIndex = 0

        workflow.applyMarkAndAdvance(.pick)
        let firstEvent = workflow.lastMarkEvent

        workflow.applyMarkAndAdvance(.pick)
        let secondEvent = workflow.lastMarkEvent

        #expect(firstEvent != secondEvent)
    }
}
