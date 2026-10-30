import Foundation

/// Identifies the folder a window shows, in a form that survives relaunching:
/// the folder's URL plus a security-scoped bookmark that regrants sandbox
/// access to it. Used as the value of a folder window, so two references are
/// equal when they name the same folder — opening a folder that's already
/// open brings its window forward instead of opening another. Does not hold
/// the access itself; FolderSession does that.
nonisolated struct FolderReference: Codable, Hashable {
    let url: URL
    let bookmark: Data

    /// Makes a reference to a folder the user has just chosen, while access
    /// to it is still granted.
    static func make(for url: URL) throws -> FolderReference {
        let bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        return FolderReference(url: url, bookmark: bookmark)
    }

    /// The folder's current URL with sandbox access restored. Throws if the
    /// bookmark can no longer be resolved, such as when the folder has been
    /// deleted.
    func resolve() throws -> URL {
        try resolveBookmark().url
    }

    /// A new reference with a freshly made bookmark, when the system reports
    /// this one as stale (as it can after the folder is moved or renamed),
    /// or nil when this one is still good. Stale bookmarks still resolve for
    /// now but may stop working, so a stale one should be replaced wherever
    /// it's kept. Throws if the bookmark can't be resolved or remade.
    func refreshedIfStale() throws -> FolderReference? {
        let (currentURL, isStale) = try resolveBookmark()
        guard isStale else { return nil }
        let isAccessing = currentURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                currentURL.stopAccessingSecurityScopedResource()
            }
        }
        return try .make(for: currentURL)
    }

    /// Resolves the bookmark to the folder's current URL, noting whether the
    /// system considers the bookmark stale.
    private func resolveBookmark() throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return (url, isStale)
    }

    /// Whether the URL is this reference's folder, however it's spelled.
    func names(_ otherURL: URL) -> Bool {
        Self.canonicalPath(of: otherURL) == canonicalPath
    }

    /// The folder's path in a canonical form, so differently spelled URLs
    /// for the same folder compare equal.
    private var canonicalPath: String {
        Self.canonicalPath(of: url)
    }

    /// A URL's path in a canonical form.
    private static func canonicalPath(of url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    static func == (lhs: FolderReference, rhs: FolderReference) -> Bool {
        lhs.canonicalPath == rhs.canonicalPath
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(canonicalPath)
    }
}
