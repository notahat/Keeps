import Foundation

/// Owns one open photo folder: the scan and the resulting photos, which
/// don't change while the folder is open.
///
/// FolderSession doesn't manage sandbox access to the folder, because AppKit
/// grants that when it opens the folder as a document. It doesn't hold the
/// grouping either; Grouping does.
@MainActor
final class FolderSession {
    /// The open folder.
    let folderURL: URL

    /// The folder's photos, in chronological order.
    let photos: [PhotoItem]

    /// Scan the folder. Throw when the folder cannot be read.
    init(folderURL: URL) throws {
        self.folderURL = folderURL
        photos = try FolderScanner.scan(url: folderURL)
    }
}
