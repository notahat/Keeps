import Foundation
@testable import Keeps
import Testing

@MainActor
struct FolderSessionTests {
    @Test("A session holds the photos scanned from its folder")
    func scansFolder() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try makeFile(named: "IMG_0001.CR3", in: folder)
        try makeFile(named: "IMG_0002.jpg", in: folder)

        let session = try FolderSession(folderURL: folder)

        #expect(session.photos.map(\.stem) == ["IMG_0001", "IMG_0002"])
    }

    @Test("Opening a session on a folder that can't be read throws")
    func unreadableFolderThrows() {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        #expect(throws: (any Error).self) {
            _ = try FolderSession(folderURL: folder)
        }
    }
}
