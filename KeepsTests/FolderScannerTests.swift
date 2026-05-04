import Foundation
@testable import Keeps
import Testing

struct FolderScannerTests {
    @Test func producesNoItemsForEmptyFolder() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let items = try FolderScanner.scan(url: folder)

        #expect(items.isEmpty)
    }

    @Test func producesOneItemForStandaloneRaw() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.CR3", in: folder)

        let items = try FolderScanner.scan(url: folder)

        #expect(items.count == 1)
        #expect(items[0].stem == "IMG_0001")
        #expect(items[0].rawURL != nil)
        #expect(items[0].jpegURL == nil)
    }

    @Test func producesOneItemForStandaloneJpeg() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.jpg", in: folder)

        let items = try FolderScanner.scan(url: folder)

        #expect(items.count == 1)
        #expect(items[0].stem == "IMG_0001")
        #expect(items[0].rawURL == nil)
        #expect(items[0].jpegURL != nil)
    }

    @Test func pairsRawAndJpegWithMatchingStem() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.CR3", in: folder)
        try makeFile(named: "IMG_0001.jpg", in: folder)

        let items = try FolderScanner.scan(url: folder)

        #expect(items.count == 1)
        #expect(items[0].rawURL != nil)
        #expect(items[0].jpegURL != nil)
    }

    @Test func keepsSeparateItemsForDifferentStems() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.CR3", in: folder)
        try makeFile(named: "IMG_0002.jpg", in: folder)

        let items = try FolderScanner.scan(url: folder)

        #expect(items.count == 2)
    }

    @Test func ignoresNonImageFiles() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.CR3", in: folder)
        try makeFile(named: "notes.txt", in: folder)
        try makeFile(named: ".DS_Store", in: folder)

        let items = try FolderScanner.scan(url: folder)

        #expect(items.count == 1)
    }

    @Test func sortsByFileCreationDate() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        // Files are created sequentially, so creation-date order matches
        // the order we create them here.
        try makeFile(named: "bravo.jpg", in: folder)
        try makeFile(named: "Alpha.jpg", in: folder)
        try makeFile(named: "charlie.jpg", in: folder)

        let items = try FolderScanner.scan(url: folder)

        #expect(items.map(\.stem) == ["bravo", "Alpha", "charlie"])
    }

    @Test func throwsWhenFolderDoesNotExist() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        #expect(throws: (any Error).self) {
            try FolderScanner.scan(url: folder)
        }
    }
}
