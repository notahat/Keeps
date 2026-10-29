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
        var isStale = false
        return try URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    /// The folder's path in a canonical form, so differently spelled URLs
    /// for the same folder compare equal.
    private var canonicalPath: String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    static func == (lhs: FolderReference, rhs: FolderReference) -> Bool {
        lhs.canonicalPath == rhs.canonicalPath
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(canonicalPath)
    }
}
