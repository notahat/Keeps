import AppKit
import Foundation
import Observation

/// Opens and restores photo folders for the app shell. Owns the current
/// folder session, the error from the most recent failed open, and the
/// security-scoped bookmark that lets the app reopen the last folder on
/// launch. Everything shown inside an open folder belongs to the workflow.
///
/// This is a class rather than a closure so that it can be stored in
/// `FocusedValues` without invalidating readers on every update: SwiftUI
/// compares class references by identity, but cannot compare closures.
@MainActor
@Observable
final class FolderOpener {
    private(set) var session: FolderSession?
    private(set) var folderError: Error?

    /// Shows the open panel and starts a session for the chosen folder.
    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        saveBookmark(for: url)
        startSession(for: url)
    }

    /// Reopens the folder recorded in the saved bookmark, if there is one.
    func restoreLastFolder() {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return }

        if isStale {
            saveBookmark(for: url)
        }
        startSession(for: url)
    }

    /// Replaces the current session with one for the given folder, recording
    /// the error instead if the folder can't be read.
    private func startSession(for url: URL) {
        folderError = nil
        do {
            session = try FolderSession(folderURL: url)
        } catch {
            session = nil
            folderError = error
        }
    }

    /// Stores a security-scoped bookmark so the folder can be reopened later.
    private func saveBookmark(for url: URL) {
        let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: Self.bookmarkKey)
    }

    private static let bookmarkKey = "lastFolderBookmark"
}
