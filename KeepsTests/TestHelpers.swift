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

/// Creates a FolderLibrary with the given number of photos and an
/// initialized first pass, ready for marking tests.
func makeLibrary(photoCount: Int) throws -> FolderLibrary {
    let folder = try makeTemporaryFolder()
    for index in 1 ... photoCount {
        try makeFile(named: String(format: "IMG_%04d.CR3", index), in: folder)
    }
    let library = FolderLibrary()
    library.openFolder(url: folder)
    library.initializeFreshPasses()
    return library
}
