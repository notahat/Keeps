import Foundation
@testable import Keeps
import Testing

/// An observable selection, standing in for Grouping, whose changes should
/// trigger saves.
@Observable
private final class ObservableSelection {
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
        let selection = ObservableSelection()
        keepsFile.startAutoSaving(
            snapshot: { makeSavedGrouping(selectedStem: selection.selectedStem) },
            onSaveError: { _ in }
        )

        // The save runs on the next main-actor turn; yield until it has.
        selection.selectedStem = "IMG_0001"
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
        let selection = ObservableSelection()
        let reported = ReportedError()
        keepsFile.startAutoSaving(
            snapshot: { makeSavedGrouping(selectedStem: selection.selectedStem) },
            onSaveError: { reported.error = $0 }
        )

        selection.selectedStem = "IMG_0001"
        for _ in 0 ..< 10 where reported.error == nil {
            await Task.yield()
        }

        #expect(reported.error != nil)
    }

    @Test("Stopping halts observed saves")
    func stopHaltsObservedSaves() async throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let keepsFile = KeepsFile(folderURL: folder)
        let selection = ObservableSelection()
        keepsFile.startAutoSaving(
            snapshot: { makeSavedGrouping(selectedStem: selection.selectedStem) },
            onSaveError: { _ in }
        )

        keepsFile.stopAutoSaving()
        selection.selectedStem = "IMG_0001"
        for _ in 0 ..< 10 {
            await Task.yield()
        }

        #expect(try keepsFile.restore() == nil)
    }
}

/// The error a save reported, if any, kept so the test can check it.
@MainActor
private final class ReportedError {
    var error: Error?
}
