import Foundation
@testable import Keeps
import Testing

struct GroupCullStateTests {
    @Test("Boundaries, collapse point, and selection survive a save and restore")
    func roundTrip() {
        let workflow = makeGroupCullWorkflow(photoCount: 10, collapsedBoundaries: [3], boundaries: [5, 10])
        workflow.selectCell(at: 2)

        let restored = GroupCullWorkflow(items: workflow.items)
        restored.applyRestored(state: workflow.snapshotState())

        #expect(restored.boundaries == [3, 5, 10])
        #expect(restored.collapsedUpTo == 3)
        #expect(restored.selectedPhotoIndex == workflow.selectedPhotoIndex)
    }

    @Test("The scroll position survives a save and restore")
    func scrollAnchorRoundTrip() {
        let workflow = makeGroupCullWorkflow(photoCount: 10)
        workflow.updateScrollAnchor(GridScrollAnchor(itemID: workflow.items[6].id, offsetFromRowTop: 42))

        let restored = GroupCullWorkflow(items: workflow.items)
        restored.applyRestored(state: workflow.snapshotState())

        #expect(restored.scrollAnchor == GridScrollAnchor(itemID: workflow.items[6].id, offsetFromRowTop: 42))
    }

    @Test("A collapse point after the last photo survives a save and restore")
    func collapseToEndRoundTrip() {
        let workflow = makeGroupCullWorkflow(photoCount: 10, collapsedBoundaries: [4, 10])

        let restored = GroupCullWorkflow(items: workflow.items)
        restored.applyRestored(state: workflow.snapshotState())

        #expect(restored.collapsedUpTo == 10)
    }

    @Test("A new workflow saves no groups, collapse, selection, or scroll position")
    func emptySnapshot() {
        let workflow = makeGroupCullWorkflow(photoCount: 3)

        #expect(workflow.snapshotState() == GroupCullState(
            boundaries: [], collapsedUpTo: nil, selectedStem: nil, scrollAnchor: nil
        ))
    }

    @Test("Positions are written readably and read back")
    func positionJSON() throws {
        let positions: [GroupCullState.Position] = [.beforePhoto("IMG_0042"), .end]

        let json = try String(decoding: JSONEncoder().encode(positions), as: UTF8.self)
        let decoded = try JSONDecoder().decode([GroupCullState.Position].self, from: Data(json.utf8))

        #expect(json == #"[{"before":"IMG_0042"},"end"]"#)
        #expect(decoded == positions)
    }

    @Test("Restoring drops anything that refers to a photo no longer in the folder")
    func missingStemsDropped() {
        let workflow = makeGroupCullWorkflow(photoCount: 5)
        let state = GroupCullState(
            boundaries: [.beforePhoto(workflow.items[2].stem), .beforePhoto("IMG_9999")],
            collapsedUpTo: .beforePhoto("IMG_8888"),
            selectedStem: "IMG_7777",
            scrollAnchor: GroupCullState.ScrollAnchor(stem: "IMG_6666", offsetFromRowTop: 10)
        )

        workflow.applyRestored(state: state)

        #expect(workflow.boundaries == [2])
        #expect(workflow.collapsedUpTo == 0)
        #expect(workflow.selectedPhotoIndex == nil)
        #expect(workflow.scrollAnchor == nil)
    }
}
