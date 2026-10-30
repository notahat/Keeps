import Foundation
import Observation

/// Owns one open photo folder: the scan and the resulting items. Does not
/// manage sandbox access to the folder; AppKit grants that when it opens the
/// folder as a document. Does not hold any workflow state — that belongs to
/// whichever workflow is driving the app.
@Observable
@MainActor
final class FolderSession {
    let folderURL: URL
    private(set) var items: [PhotoItem]

    /// Scans the folder. Throws when the folder cannot be read.
    init(folderURL: URL) throws {
        self.folderURL = folderURL
        items = try FolderScanner.scan(url: folderURL)
    }
}
