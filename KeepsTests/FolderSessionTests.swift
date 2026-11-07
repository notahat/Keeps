import Foundation
@testable import Keeps
import Testing

struct FolderSessionTests {
    @MainActor @Test func scansTheFolderIntoPhotos() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.CR3", in: folder)
        try makeFile(named: "IMG_0002.jpg", in: folder)

        let session = try FolderSession(folderURL: folder)

        #expect(session.folderURL == folder)
        #expect(session.photos.count == 2)
    }

    @MainActor @Test func throwsWhenTheFolderCannotBeRead() {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        #expect(throws: (any Error).self) {
            _ = try FolderSession(folderURL: folder)
        }
    }

    @MainActor @Test func photoSourceURLPrefersRawOverJpeg() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeFile(named: "IMG_0001.NEF", in: folder)
        try makeFile(named: "IMG_0001.jpg", in: folder)

        let session = try FolderSession(folderURL: folder)

        #expect(session.photos[0].sourceURL.pathExtension.lowercased() == "nef")
    }
}
