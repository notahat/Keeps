import Foundation
@testable import Keeps
import Testing

struct SavedGroupingTests {
    @Test("Boundaries, collapse point, and selection survive a save and restore")
    func roundTrip() {
        let grouping = makeGrouping(photoCount: 10, collapsedBoundaries: [3], boundaries: [5, 10])
        grouping.selectCell(at: 2)

        let restored = Grouping(items: grouping.items)
        restored.applyRestored(state: grouping.snapshotState())

        #expect(restored.boundaries == [3, 5, 10])
        #expect(restored.collapsedUpTo == 3)
        #expect(restored.selectedPhotoIndex == grouping.selectedPhotoIndex)
    }

    @Test("The scroll position survives a save and restore")
    func scrollAnchorRoundTrip() {
        let grouping = makeGrouping(photoCount: 10)
        grouping.scrollAnchor = GridScrollAnchor(itemID: grouping.items[6].id, offsetFromRowTop: 42)

        let restored = Grouping(items: grouping.items)
        restored.applyRestored(state: grouping.snapshotState())

        #expect(restored.scrollAnchor == GridScrollAnchor(itemID: grouping.items[6].id, offsetFromRowTop: 42))
    }

    @Test("Keepers and done groups survive a save to keeps.json and a restore")
    func pickingRoundTrip() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let grouping = makeGrouping(photoCount: 10, boundaries: [3, 6])
        grouping.open(groupAtCell: 0)
        grouping.toggleKeeper(atPhoto: 1)
        grouping.markOpenGroupDone()
        grouping.toggleKeeper(atPhoto: 4)
        let keepsFile = KeepsFile(folderURL: folder)

        try keepsFile.save(grouping.snapshotState())
        let restored = Grouping(items: grouping.items)
        try restored.applyRestored(state: #require(try keepsFile.restore()))

        #expect(restored.keepers == [1, 4])
        #expect(restored.isDone(0 ..< 3))
        #expect(!restored.isDone(3 ..< 6))
    }

    @Test("A collapse point after the last photo survives a save and restore")
    func collapseToEndRoundTrip() {
        let grouping = makeGrouping(photoCount: 10, collapsedBoundaries: [4, 10])

        let restored = Grouping(items: grouping.items)
        restored.applyRestored(state: grouping.snapshotState())

        #expect(restored.collapsedUpTo == 10)
    }

    @Test("A new grouping saves no groups, collapse, selection, or scroll position")
    func emptySnapshot() {
        let grouping = makeGrouping(photoCount: 3)

        #expect(grouping.snapshotState() == SavedGrouping(
            boundaries: [], collapsedUpTo: nil, selectedStem: nil, scrollAnchor: nil
        ))
    }

    @Test("Positions are written readably and read back")
    func positionJSON() throws {
        let positions: [SavedGrouping.Position] = [.beforePhoto("IMG_0042"), .end]

        let json = try String(decoding: JSONEncoder().encode(positions), as: UTF8.self)
        let decoded = try JSONDecoder().decode([SavedGrouping.Position].self, from: Data(json.utf8))

        #expect(json == #"[{"before":"IMG_0042"},"end"]"#)
        #expect(decoded == positions)
    }

    /// The fixture is written out by hand rather than produced by the encoder,
    /// so a change to SavedGrouping that would stop existing keeps.json files
    /// loading makes this fail. Don't edit the fixture to make it pass: add a
    /// conversion from this format instead.
    @Test("A keeps.json saved in the original group-cull format still restores")
    func originalFormatRestores() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let json = """
        {
          "state" : {
            "boundaries" : [
              { "before" : "IMG_0004" },
              { "before" : "IMG_0006" },
              "end"
            ],
            "collapsedUpTo" : { "before" : "IMG_0004" },
            "scrollAnchor" : { "offsetFromRowTop" : 42.5, "stem" : "IMG_0007" },
            "selectedStem" : "IMG_0005"
          },
          "workflow" : "group-cull"
        }
        """
        try Data(json.utf8).write(to: folder.appendingPathComponent("keeps.json"))
        let grouping = makeGrouping(photoCount: 10)
        let keepsFile = KeepsFile(folderURL: folder)

        let state = try #require(try keepsFile.restore())
        grouping.applyRestored(state: state)

        #expect(grouping.boundaries == [3, 5, 10])
        #expect(grouping.collapsedUpTo == 3)
        #expect(grouping.selectedPhotoIndex == 4)
        #expect(grouping.scrollAnchor == GridScrollAnchor(itemID: grouping.items[6].id, offsetFromRowTop: 42.5))
    }

    @Test("Restoring drops anything that refers to a photo no longer in the folder")
    func missingStemsDropped() {
        let grouping = makeGrouping(photoCount: 5)
        let state = SavedGrouping(
            boundaries: [.beforePhoto(grouping.items[2].stem), .beforePhoto("IMG_9999")],
            collapsedUpTo: .beforePhoto("IMG_8888"),
            selectedStem: "IMG_7777",
            scrollAnchor: SavedGrouping.ScrollAnchor(stem: "IMG_6666", offsetFromRowTop: 10),
            keeperStems: [grouping.items[1].stem, "IMG_5555"],
            doneGroupStartStems: [grouping.items[0].stem, "IMG_4444"]
        )

        grouping.applyRestored(state: state)

        #expect(grouping.boundaries == [2])
        #expect(grouping.collapsedUpTo == 0)
        #expect(grouping.selectedPhotoIndex == nil)
        #expect(grouping.scrollAnchor == nil)
        #expect(grouping.keepers == [1])
        #expect(grouping.isDone(0 ..< 2))
    }
}
