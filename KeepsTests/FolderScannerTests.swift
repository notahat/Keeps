import Foundation
@testable import Keeps
import Testing

struct FolderScannerTests {
    @Test("An empty folder has no photos")
    func emptyFolder() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let photos = try FolderScanner.scan(url: folder)

        #expect(photos.isEmpty)
    }

    @Test("A RAW file on its own is a photo with no JPEG")
    func standaloneRaw() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try makeFile(named: "IMG_0001.CR3", in: folder)

        let photos = try FolderScanner.scan(url: folder)

        try #require(photos.count == 1)
        #expect(photos[0].rawURL?.lastPathComponent == "IMG_0001.CR3")
        #expect(photos[0].jpegURL == nil)
    }

    @Test("A JPEG on its own is a photo with no RAW file")
    func standaloneJpeg() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try makeFile(named: "IMG_0001.jpg", in: folder)

        let photos = try FolderScanner.scan(url: folder)

        try #require(photos.count == 1)
        #expect(photos[0].rawURL == nil)
        #expect(photos[0].jpegURL?.lastPathComponent == "IMG_0001.jpg")
    }

    @Test("A RAW file and a JPEG with the same stem are one photo")
    func pairsRawAndJpeg() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try makeFile(named: "IMG_0001.CR3", in: folder)
        try makeFile(named: "IMG_0001.jpg", in: folder)

        let photos = try FolderScanner.scan(url: folder)

        try #require(photos.count == 1)
        #expect(photos[0].rawURL?.lastPathComponent == "IMG_0001.CR3")
        #expect(photos[0].jpegURL?.lastPathComponent == "IMG_0001.jpg")
    }

    @Test("A photo's stem is its file name without the extension")
    func stemIsFileNameWithoutExtension() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try makeFile(named: "IMG_0001.CR3", in: folder)

        let photos = try FolderScanner.scan(url: folder)

        #expect(photos.map(\.stem) == ["IMG_0001"])
    }

    @Test("Files with different stems are separate photos")
    func differentStemsAreSeparate() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try makeFile(named: "IMG_0001.CR3", in: folder)
        try makeFile(named: "IMG_0002.jpg", in: folder)

        let photos = try FolderScanner.scan(url: folder)

        #expect(photos.count == 2)
    }

    @Test("Files that aren't images are ignored")
    func ignoresOtherFiles() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try makeFile(named: "IMG_0001.CR3", in: folder)
        try makeFile(named: "notes.txt", in: folder)
        try makeFile(named: ".DS_Store", in: folder)

        let photos = try FolderScanner.scan(url: folder)

        #expect(photos.count == 1)
    }

    @Test("Photos are in the order their files were created")
    func sortsByCreationDate() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        // The files are created one after another, so their creation dates
        // follow the order here, which isn't alphabetical.
        try makeFile(named: "bravo.jpg", in: folder)
        try makeFile(named: "Alpha.jpg", in: folder)
        try makeFile(named: "charlie.jpg", in: folder)

        let photos = try FolderScanner.scan(url: folder)

        #expect(photos.map(\.stem) == ["bravo", "Alpha", "charlie"])
    }

    @Test("Scanning a folder that doesn't exist throws")
    func missingFolderThrows() {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        #expect(throws: (any Error).self) {
            try FolderScanner.scan(url: folder)
        }
    }
}
