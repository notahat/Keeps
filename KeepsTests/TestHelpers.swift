import Foundation
@testable import Keeps

func makeTemporaryFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func makeFile(named name: String, in folder: URL) throws {
    let url = folder.appendingPathComponent(name)
    try Data().write(to: url)
}

/// Creates synthetic PhotoItems with placeholder URLs for store-level tests
/// that don't need a real folder. Capture dates increase with the index.
func makePhotoItems(count: Int) -> [PhotoItem] {
    (1 ... count).map { index in
        PhotoItem(
            id: UUID(),
            stem: String(format: "IMG_%04d", index),
            rawURL: URL(fileURLWithPath: "/tmp/IMG_\(index).CR3"),
            jpegURL: nil,
            capturedAt: Date(timeIntervalSince1970: TimeInterval(index))
        )
    }
}

/// Creates a SimpleCullWorkflow with the given number of photos, ready for
/// marking tests.
func makeWorkflow(photoCount: Int) -> SimpleCullWorkflow {
    SimpleCullWorkflow(items: makePhotoItems(count: photoCount))
}
