import Foundation
@testable import Keeps
import Testing

struct FolderLibraryTests {
    @Test func openFolderPopulatesItemsFromScanner() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.CR3", in: folder)
        try makeFile(named: "IMG_0002.jpg", in: folder)

        let library = FolderLibrary()
        library.openFolder(url: folder)

        #expect(library.folderURL == folder)
        #expect(library.folderError == nil)
        #expect(library.items.count == 2)
    }

    @Test func openFolderRecordsErrorWhenFolderIsMissing() {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        let library = FolderLibrary()
        library.openFolder(url: folder)

        #expect(library.folderError != nil)
        #expect(library.items.isEmpty)
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
