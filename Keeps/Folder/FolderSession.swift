import Foundation

/// Owns one open photo folder: the scan and the resulting items, which don't
/// change while the folder is open. Does not manage sandbox access to the
/// folder; AppKit grants that when it opens the folder as a document. Does
/// not hold the grouping — that belongs to Grouping.
@MainActor
final class FolderSession {
    let folderURL: URL
    let items: [PhotoItem]

    /// Scans the folder. Throws when the folder cannot be read.
    init(folderURL: URL) throws {
        self.folderURL = folderURL
        items = try FolderScanner.scan(url: folderURL)
    }
}
