import Foundation
@testable import Keeps
import Testing

struct FolderLibraryTests {
    @Test func producesNoItemsForEmptyFolder() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let library = FolderLibrary()
        library.openFolder(url: folder)

        #expect(library.items.isEmpty)
    }

    @Test func producesOneItemForStandaloneRaw() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.CR3", in: folder)

        let library = FolderLibrary()
        library.openFolder(url: folder)

        #expect(library.items.count == 1)
        #expect(library.items[0].stem == "IMG_0001")
        #expect(library.items[0].rawURL != nil)
        #expect(library.items[0].jpegURL == nil)
    }

    @Test func producesOneItemForStandaloneJpeg() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.jpg", in: folder)

        let library = FolderLibrary()
        library.openFolder(url: folder)

        #expect(library.items.count == 1)
        #expect(library.items[0].stem == "IMG_0001")
        #expect(library.items[0].rawURL == nil)
        #expect(library.items[0].jpegURL != nil)
    }

    @Test func pairsRawAndJpegWithMatchingStem() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.CR3", in: folder)
        try makeFile(named: "IMG_0001.jpg", in: folder)

        let library = FolderLibrary()
        library.openFolder(url: folder)

        #expect(library.items.count == 1)
        #expect(library.items[0].rawURL != nil)
        #expect(library.items[0].jpegURL != nil)
    }

    @Test func keepsSeparateItemsForDifferentStems() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.CR3", in: folder)
        try makeFile(named: "IMG_0002.jpg", in: folder)

        let library = FolderLibrary()
        library.openFolder(url: folder)

        #expect(library.items.count == 2)
    }

    @Test func ignoresNonImageFiles() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.CR3", in: folder)
        try makeFile(named: "notes.txt", in: folder)
        try makeFile(named: ".DS_Store", in: folder)

        let library = FolderLibrary()
        library.openFolder(url: folder)

        #expect(library.items.count == 1)
    }

    @Test func sortsCaseInsensitivelyByStem() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "bravo.jpg", in: folder)
        try makeFile(named: "Alpha.jpg", in: folder)
        try makeFile(named: "charlie.jpg", in: folder)

        let library = FolderLibrary()
        library.openFolder(url: folder)

        #expect(library.items.map(\.stem) == ["Alpha", "bravo", "charlie"])
    }

    @Test func sourceURLPrefersRawOverJpeg() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.NEF", in: folder)
        try makeFile(named: "IMG_0001.jpg", in: folder)

        let library = FolderLibrary()
        library.openFolder(url: folder)

        #expect(library.items[0].sourceURL.pathExtension.lowercased() == "nef")
    }

    // MARK: - Helpers

    private func makeTemporaryFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeFile(named name: String, in folder: URL) throws {
        let url = folder.appendingPathComponent(name)
        try Data().write(to: url)
    }
}
