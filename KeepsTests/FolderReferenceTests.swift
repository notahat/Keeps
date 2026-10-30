import Foundation
@testable import Keeps
import Testing

struct FolderReferenceTests {
    @Test("Two references to the same folder are equal, whatever their bookmark data")
    func sameFolderIsEqual() {
        let url = URL(fileURLWithPath: "/tmp/photos", isDirectory: true)
        let first = FolderReference(url: url, bookmark: Data([1]))
        let second = FolderReference(url: url, bookmark: Data([2]))

        #expect(first == second)
        #expect(first.hashValue == second.hashValue)
    }

    @Test("References to different folders are not equal")
    func differentFoldersDiffer() {
        let first = FolderReference(url: URL(fileURLWithPath: "/tmp/a", isDirectory: true), bookmark: Data())
        let second = FolderReference(url: URL(fileURLWithPath: "/tmp/b", isDirectory: true), bookmark: Data())

        #expect(first != second)
    }

    @Test("A reference names its folder however the folder's URL is spelled")
    func namesItsFolder() {
        let reference = FolderReference(url: URL(fileURLWithPath: "/tmp/photos", isDirectory: true), bookmark: Data())

        #expect(reference.names(URL(fileURLWithPath: "/tmp/photos/")))
        #expect(reference.names(URL(fileURLWithPath: "/tmp/other/../photos")))
    }

    @Test("A reference doesn't name a different folder")
    func doesNotNameOtherFolder() {
        let reference = FolderReference(url: URL(fileURLWithPath: "/tmp/photos", isDirectory: true), bookmark: Data())

        #expect(!reference.names(URL(fileURLWithPath: "/tmp/other")))
    }

    @Test("A reference survives encoding and decoding")
    func codableRoundTrip() throws {
        let reference = FolderReference(url: URL(fileURLWithPath: "/tmp/photos", isDirectory: true), bookmark: Data([7, 8]))

        let decoded = try JSONDecoder().decode(FolderReference.self, from: JSONEncoder().encode(reference))

        #expect(decoded == reference)
        #expect(decoded.bookmark == reference.bookmark)
    }

    @Test("A reference made for a folder resolves back to that folder")
    func resolvesToFolder() throws {
        let folder = try makeTemporaryFolder()

        let resolved = try FolderReference.make(for: folder).resolve()

        #expect(resolved.resolvingSymlinksInPath().path == folder.resolvingSymlinksInPath().path)
    }

    @Test("A reference with an up-to-date bookmark needs no refreshing")
    func freshBookmarkIsNotRefreshed() throws {
        let folder = try makeTemporaryFolder()

        let refreshed = try FolderReference.make(for: folder).refreshedIfStale()

        #expect(refreshed == nil)
    }
}
