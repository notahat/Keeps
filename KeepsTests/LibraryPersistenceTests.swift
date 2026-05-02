import Foundation
@testable import Keeps
import Testing

@MainActor
struct LibraryPersistenceTests {
    @Test func restoreFallsBackToFreshPassWhenNoFileExists() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.CR3", in: folder)
        let library = FolderLibrary()
        library.openFolder(url: folder)

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

        let library = FolderLibrary()
        library.openFolder(url: folder)
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

        let library = FolderLibrary()
        library.openFolder(url: folder)
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

        let library = FolderLibrary()
        library.openFolder(url: folder)
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

    @Test func groupsRoundTripThroughSaveAndRestore() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.CR3", in: folder)
        try makeFile(named: "IMG_0002.CR3", in: folder)
        try makeFile(named: "IMG_0003.CR3", in: folder)

        let library = FolderLibrary()
        library.openFolder(url: folder)
        let persistence = LibraryPersistence(folderURL: folder)
        persistence.restore(into: library)

        library.selectItem(at: 0)
        library.extendSelection(to: 1)
        library.createGroupFromSelection()
        let savedColor = library.groupColor(for: library.items[0].id)

        persistence.save(library)

        let library2 = FolderLibrary()
        library2.openFolder(url: folder)
        let persistence2 = LibraryPersistence(folderURL: folder)
        persistence2.restore(into: library2)

        #expect(library2.groups.count == 1)
        #expect(library2.groupColor(for: library2.items[0].id) == savedColor)
        #expect(library2.groupColor(for: library2.items[1].id) == savedColor)
        #expect(library2.groupColor(for: library2.items[2].id) == nil)
    }

    @Test func restoreDropsOrphanedStemsInGroups() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.CR3", in: folder)
        // keeps.json references IMG_0002 in a group but it no longer exists on disk.
        try writeKeepsJson(
            to: folder,
            passes: [["picks": [], "rejects": []]],
            groups: [LibraryState.PhotoGroup(id: UUID(), colorIndex: 0, stems: ["IMG_0001", "IMG_0002"])]
        )

        let library = FolderLibrary()
        library.openFolder(url: folder)
        let persistence = LibraryPersistence(folderURL: folder)
        persistence.restore(into: library)

        #expect(library.groups.count == 1)
        #expect(library.groups[0].itemIDs.count == 1)
    }

    @Test func restoreWithNoGroupsKeyInJsonLoadsCleanly() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.CR3", in: folder)
        // Write old-format JSON with no "groups" key.
        let oldFormatJSON = #"{"passes":[{"picks":[],"rejects":[]}]}"#
        try oldFormatJSON.data(using: .utf8)?.write(to: folder.appendingPathComponent("keeps.json"))

        let library = FolderLibrary()
        library.openFolder(url: folder)
        let persistence = LibraryPersistence(folderURL: folder)
        persistence.restore(into: library)

        #expect(library.groups.isEmpty)
    }

    private func writeKeepsJson(
        to folder: URL,
        passes: [[String: [String]]],
        groups: [LibraryState.PhotoGroup] = []
    ) throws {
        let passObjects = passes.map { dict in
            LibraryState.Pass(
                picks: dict["picks"] ?? [],
                rejects: dict["rejects"] ?? []
            )
        }
        let state = LibraryState(passes: passObjects, groups: groups)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: folder.appendingPathComponent("keeps.json"))
    }
}
