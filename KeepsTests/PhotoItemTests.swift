import Foundation
@testable import Keeps
import Testing

struct PhotoItemTests {
    @Test("A photo's source is its RAW file when it has one")
    func sourcePrefersRaw() {
        let photo = PhotoItem(
            id: UUID(),
            stem: "IMG_0001",
            rawURL: URL(fileURLWithPath: "/tmp/IMG_0001.NEF"),
            jpegURL: URL(fileURLWithPath: "/tmp/IMG_0001.jpg"),
            fileCreationDate: Date()
        )

        #expect(photo.sourceURL.lastPathComponent == "IMG_0001.NEF")
    }

    @Test("A photo's source is its JPEG when it has no RAW file")
    func sourceFallsBackToJpeg() {
        let photo = PhotoItem(
            id: UUID(),
            stem: "IMG_0001",
            rawURL: nil,
            jpegURL: URL(fileURLWithPath: "/tmp/IMG_0001.jpg"),
            fileCreationDate: Date()
        )

        #expect(photo.sourceURL.lastPathComponent == "IMG_0001.jpg")
    }
}
