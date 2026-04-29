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

    @Test func sortsByFileCreationDate() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        // Files are created sequentially, so creation-date order matches
        // the order we create them here.
        try makeFile(named: "bravo.jpg", in: folder)
        try makeFile(named: "Alpha.jpg", in: folder)
        try makeFile(named: "charlie.jpg", in: folder)

        let library = FolderLibrary()
        library.openFolder(url: folder)

        #expect(library.items.map(\.stem) == ["bravo", "Alpha", "charlie"])
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
}
