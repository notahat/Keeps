import Foundation
import Observation

/// Owns one open photo folder: the security-scoped access, the scan, and the
/// resulting items. Access begins on init and ends on deinit, so the folder
/// stays readable for as long as the session is alive. Does not hold any
/// workflow state — that belongs to whichever workflow is driving the app.
@Observable
@MainActor
final class FolderSession {
    let folderURL: URL
    private(set) var items: [PhotoItem]

    /// Starts security-scoped access and scans the folder. Throws when the
    /// folder cannot be read; access is released before rethrowing because
    /// deinit does not run for a partially initialised object.
    init(folderURL: URL) throws {
        self.folderURL = folderURL
        _ = folderURL.startAccessingSecurityScopedResource()
        do {
            items = try FolderScanner.scan(url: folderURL)
        } catch {
            folderURL.stopAccessingSecurityScopedResource()
            throw error
        }
    }

    deinit {
        folderURL.stopAccessingSecurityScopedResource()
    }
}
