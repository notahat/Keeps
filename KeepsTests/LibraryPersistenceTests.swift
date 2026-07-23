import Foundation
@testable import Keeps
import Testing

@MainActor
struct LibraryPersistenceTests {
    @Test func restoreFallsBackToFreshPassWhenNoFileExists() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.CR3", in: folder)
        let library = FolderLibrary(items: try FolderScanner.scan(url: folder))

        let persistence = LibraryPersistence(folderURL: folder)
        persistence.restore(into: library)

        #expect(library.passes.count == 1)
        #expect(library.passes[0].picks.isEmpty)
        #expect(library.passes[0].rejects.isEmpty)
    }

    @Test func restoresMarksFromKeepsJson() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.CR3", in: folder)
        try makeFile(named: "IMG_0002.CR3", in: folder)
        try makeFile(named: "IMG_0003.CR3", in: folder)
        try writeKeepsJson(
            to: folder,
            passes: [["picks": ["IMG_0001"], "rejects": ["IMG_0002"]]]
        )

        let library = FolderLibrary(items: try FolderScanner.scan(url: folder))
        let persistence = LibraryPersistence(folderURL: folder)
        persistence.restore(into: library)

        let itemByName = Dictionary(uniqueKeysWithValues: library.items.map { ($0.stem, $0) })
        #expect(try library.mark(for: #require(itemByName["IMG_0001"]?.id)) == .pick)
        #expect(try library.mark(for: #require(itemByName["IMG_0002"]?.id)) == .reject)
        #expect(try library.mark(for: #require(itemByName["IMG_0003"]?.id)) == nil)
    }

    @Test func restoreDropsOrphanedStems() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.CR3", in: folder)
        // keeps.json references IMG_0002 which no longer exists on disk.
        try writeKeepsJson(
            to: folder,
            passes: [["picks": ["IMG_0001", "IMG_0002"], "rejects": []]]
        )

        let library = FolderLibrary(items: try FolderScanner.scan(url: folder))
        let persistence = LibraryPersistence(folderURL: folder)
        persistence.restore(into: library)

        #expect(library.passes[0].picks.count == 1)
    }

    @Test func restoresMultiplePasses() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.CR3", in: folder)
        try makeFile(named: "IMG_0002.CR3", in: folder)
        try makeFile(named: "IMG_0003.CR3", in: folder)
        try writeKeepsJson(
            to: folder,
            passes: [
                ["picks": ["IMG_0001"], "rejects": []],
                ["picks": ["IMG_0002"], "rejects": []],
            ]
        )

        let library = FolderLibrary(items: try FolderScanner.scan(url: folder))
        let persistence = LibraryPersistence(folderURL: folder)
        persistence.restore(into: library)

        #expect(library.passes.count == 2)
        #expect(library.currentPassIndex == 1)
    }

    @Test func libraryStateCodableRoundTrip() throws {
        let state = LibraryState(
            passes: [
                LibraryState.Pass(picks: ["IMG_0001", "IMG_0003"], rejects: ["IMG_0002"]),
                LibraryState.Pass(picks: ["IMG_0004"], rejects: []),
            ]
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(LibraryState.self, from: data)

        #expect(decoded.passes.count == 2)
        #expect(decoded.passes[0].picks == ["IMG_0001", "IMG_0003"])
        #expect(decoded.passes[0].rejects == ["IMG_0002"])
        #expect(decoded.passes[1].picks == ["IMG_0004"])
        #expect(decoded.passes[1].rejects == [])
    }

    @Test func saveThrowsWhenFileCannotBeWritten() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.CR3", in: folder)
        // Pre-create a directory at the keeps.json path so that the save's
        // file write cannot succeed.
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("keeps.json"),
            withIntermediateDirectories: false
        )

        let library = FolderLibrary(items: try FolderScanner.scan(url: folder))
        let persistence = LibraryPersistence(folderURL: folder)
        persistence.restore(into: library)

        #expect(throws: (any Error).self) {
            try persistence.save(library)
        }
    }

    @Test func observedSaveFailureRecordsErrorOnLibrary() async throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.CR3", in: folder)
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("keeps.json"),
            withIntermediateDirectories: false
        )

        let library = FolderLibrary(items: try FolderScanner.scan(url: folder))
        let persistence = LibraryPersistence(folderURL: folder)
        persistence.restore(into: library)
        persistence.startObserving(library)

        // Trigger an observed change. The save runs on the next main-actor turn;
        // yield until the observation closure has had a chance to run.
        library.applyMarkAndAdvance(.pick)
        for _ in 0 ..< 10 where library.saveError == nil {
            await Task.yield()
        }

        #expect(library.saveError != nil)
    }

    private func writeKeepsJson(
        to folder: URL,
        passes: [[String: [String]]]
    ) throws {
        let passObjects = passes.map { dict in
            LibraryState.Pass(
                picks: dict["picks"] ?? [],
                rejects: dict["rejects"] ?? []
            )
        }
        let state = LibraryState(passes: passObjects)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: folder.appendingPathComponent("keeps.json"))
    }
}
