import Foundation
@testable import Keeps
import Testing

/// A minimal observable model for exercising observation-triggered saves.
@Observable
private final class StubModel {
    var selectedStem: String?
}

/// Makes a saved grouping that differs only in its selection, which is enough
/// to tell one save from another.
private func makeSavedGrouping(selectedStem: String?) -> SavedGrouping {
    SavedGrouping(boundaries: [], collapsedUpTo: nil, selectedStem: selectedStem, scrollAnchor: nil)
}

@MainActor
struct KeepsFileTests {
    @Test("A saved grouping is restored as it was saved")
    func roundTrip() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let keepsFile = KeepsFile(folderURL: folder)
        let saved = SavedGrouping(
            boundaries: [.beforePhoto("IMG_0002"), .end],
            collapsedUpTo: .beforePhoto("IMG_0002"),
            selectedStem: "IMG_0001",
            scrollAnchor: SavedGrouping.ScrollAnchor(stem: "IMG_0001", offsetFromRowTop: 3)
        )

        try keepsFile.save(saved)
        let restored = try keepsFile.restore()

        #expect(restored == saved)
    }

    @Test("Saving writes the original format's name")
    func saveWritesFormatName() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let keepsFile = KeepsFile(folderURL: folder)

        try keepsFile.save(makeSavedGrouping(selectedStem: nil))
        let data = try Data(contentsOf: folder.appendingPathComponent("keeps.json"))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["workflow"] as? String == "group-cull")
    }

    @Test("A grouping is restored from a file that also has entries it doesn't know")
    func restoreIgnoresOtherEntries() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let json = """
        {"state": {"boundaries": [], "selectedStem": "IMG_0001"}, "windowFrame": [[1, 2], [3, 4]], "workflow": "group-cull"}
        """
        try Data(json.utf8).write(to: folder.appendingPathComponent("keeps.json"))
        let keepsFile = KeepsFile(folderURL: folder)

        let restored = try keepsFile.restore()

        #expect(restored == makeSavedGrouping(selectedStem: "IMG_0001"))
    }

    @Test("Restores nothing when there is no keeps.json")
    func restoreWithNoFile() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let keepsFile = KeepsFile(folderURL: folder)

        #expect(try keepsFile.restore() == nil)
    }

    @Test("Refuses to restore a keeps.json in a format it doesn't know")
    func restoreWithUnknownFormat() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let json = """
        {"state": {"boundaries": [], "selectedStem": "IMG_0001"}, "workflow": "some-other-format"}
        """
        try Data(json.utf8).write(to: folder.appendingPathComponent("keeps.json"))

        let keepsFile = KeepsFile(folderURL: folder)

        #expect(throws: KeepsFile.UnreadableFileError.self) {
            try keepsFile.restore()
        }
    }

    @Test("Refuses to restore a keeps.json that isn't JSON")
    func restoreWithInvalidJSON() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data("not json".utf8).write(to: folder.appendingPathComponent("keeps.json"))

        let keepsFile = KeepsFile(folderURL: folder)

        #expect(throws: KeepsFile.UnreadableFileError.self) {
            try keepsFile.restore()
        }
    }

    @Test("Refuses to restore a keeps.json that is missing its grouping")
    func restoreWithMissingGrouping() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data(#"{"workflow": "group-cull"}"#.utf8).write(to: folder.appendingPathComponent("keeps.json"))

        let keepsFile = KeepsFile(folderURL: folder)

        #expect(throws: KeepsFile.UnreadableFileError.self) {
            try keepsFile.restore()
        }
    }

    @Test("Saving throws when keeps.json can't be written")
    func saveFailureThrows() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        // Pre-create a directory at the keeps.json path so the write fails.
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("keeps.json"),
            withIntermediateDirectories: false
        )
        let keepsFile = KeepsFile(folderURL: folder)

        #expect(throws: (any Error).self) {
            try keepsFile.save(makeSavedGrouping(selectedStem: nil))
        }
    }

    @Test("An observed change saves a fresh snapshot")
    func observedChangeSaves() async throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let keepsFile = KeepsFile(folderURL: folder)
        let model = StubModel()
        keepsFile.startAutoSaving(
            snapshot: { makeSavedGrouping(selectedStem: model.selectedStem) },
            onSaveError: { _ in }
        )

        // The save runs on the next main-actor turn; yield until it has.
        model.selectedStem = "IMG_0001"
        for _ in 0 ..< 10 where try keepsFile.restore() == nil {
            await Task.yield()
        }

        #expect(try keepsFile.restore() == makeSavedGrouping(selectedStem: "IMG_0001"))
    }

    @Test("A failed observed save reports the error")
    func observedSaveFailureReported() async throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("keeps.json"),
            withIntermediateDirectories: false
        )
        let keepsFile = KeepsFile(folderURL: folder)
        let model = StubModel()
        let errorBox = ErrorBox()
        keepsFile.startAutoSaving(
            snapshot: { makeSavedGrouping(selectedStem: model.selectedStem) },
            onSaveError: { errorBox.error = $0 }
        )

        model.selectedStem = "IMG_0001"
        for _ in 0 ..< 10 where errorBox.error == nil {
            await Task.yield()
        }

        #expect(errorBox.error != nil)
    }

    @Test("Stopping halts observed saves")
    func stopHaltsObservedSaves() async throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let keepsFile = KeepsFile(folderURL: folder)
        let model = StubModel()
        keepsFile.startAutoSaving(
            snapshot: { makeSavedGrouping(selectedStem: model.selectedStem) },
            onSaveError: { _ in }
        )

        keepsFile.stopAutoSaving()
        model.selectedStem = "IMG_0001"
        for _ in 0 ..< 10 {
            await Task.yield()
        }

        #expect(try keepsFile.restore() == nil)
    }
}

/// Captures an error reported through an escaping @MainActor callback.
@MainActor
private final class ErrorBox {
    var error: Error?
}
