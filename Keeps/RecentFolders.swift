import AppKit
import Observation

/// The folders the user has opened lately, for the Open Recent menu. A thin,
/// observable layer over the system's recent documents list, which SwiftUI
/// menus can't watch directly. The system list also gives the app sandbox
/// access to these folders again on later launches, so no bookmarks are kept
/// here. Does not open folders itself.
@Observable
final class RecentFolders {
    static let shared = RecentFolders()

    /// The recent folders, newest first.
    private(set) var urls: [URL] = NSDocumentController.shared.recentDocumentURLs

    /// Records a folder as just opened, moving it to the front of the list.
    func note(_ url: URL) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        refresh()
    }

    /// Empties the list.
    func clear() {
        NSDocumentController.shared.clearRecentDocuments(nil)
        refresh()
    }

    /// Copies the system list so observers see the change.
    private func refresh() {
        urls = NSDocumentController.shared.recentDocumentURLs
    }
}
