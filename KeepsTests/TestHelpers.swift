import Foundation
@testable import Keeps

/// Create an empty folder with a unique name in the temporary directory, and
/// return its URL. The caller removes the folder when done with it. Throw if
/// the folder can't be created.
func makeTemporaryFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// Write an empty file with the given name into a folder, replacing any file
/// already there. Throw if the file can't be written.
func makeFile(named name: String, in folder: URL) throws {
    let url = folder.appendingPathComponent(name)
    try Data().write(to: url)
}

/// Make photos with placeholder URLs, for tests that don't need a real
/// folder. Nothing exists at the URLs. Stems run from IMG_0001, and file
/// creation dates increase with the stem's number.
func makePhotos(count: Int) -> [PhotoItem] {
    (1 ... count).map { index in
        let stem = String(format: "IMG_%04d", index)
        return PhotoItem(
            id: UUID(),
            stem: stem,
            rawURL: URL(fileURLWithPath: "/tmp/\(stem).CR3"),
            jpegURL: nil,
            fileCreationDate: Date(timeIntervalSince1970: TimeInterval(index))
        )
    }
}

/// Make a Grouping of photos from makePhotos. Place `collapsedBoundaries`
/// and collapse the groups they close, then place `boundaries`, whose groups
/// stay uncollapsed. Each boundary is the index of the photo it comes
/// before, from 1 to `photoCount`.
func makeGrouping(
    photoCount: Int,
    collapsedBoundaries: Set<Int> = [],
    boundaries: Set<Int> = []
) -> Grouping {
    let grouping = Grouping(photos: makePhotos(count: photoCount))
    for boundary in collapsedBoundaries.sorted() {
        grouping.toggleBoundary(atPhoto: boundary)
    }
    if !collapsedBoundaries.isEmpty {
        grouping.collapseGroups()
    }
    for boundary in boundaries.sorted() {
        grouping.toggleBoundary(atPhoto: boundary)
    }
    return grouping
}
