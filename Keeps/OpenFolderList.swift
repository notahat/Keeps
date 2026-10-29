import Foundation

/// Remembers which folders have windows open, in the user's defaults, so the
/// app can reopen them on the next launch. Folders are added when their
/// window opens and removed when the user closes it; quitting leaves the list
/// as it is. Does not open or close windows itself.
final class OpenFolderList {
    static let shared = OpenFolderList(defaults: .standard)

    private let defaults: UserDefaults
    private static let key = "openFolders"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// The remembered folders, oldest first. Unreadable saved data counts as
    /// an empty list: this is only a convenience for the next launch, and
    /// the next change overwrites it with good data.
    var folders: [FolderReference] {
        guard let data = defaults.data(forKey: Self.key) else { return [] }
        return (try? JSONDecoder().decode([FolderReference].self, from: data)) ?? []
    }

    /// Remembers a folder, if it isn't already.
    func add(_ folder: FolderReference) {
        var updated = folders
        guard !updated.contains(folder) else { return }
        updated.append(folder)
        save(updated)
    }

    /// Swaps a remembered folder for an updated reference to it, such as one
    /// with a refreshed bookmark, keeping its place in the list. Does nothing
    /// if the folder isn't remembered.
    func replace(_ folder: FolderReference, with updated: FolderReference) {
        var folders = folders
        guard let index = folders.firstIndex(of: folder) else { return }
        folders[index] = updated
        save(folders)
    }

    /// Forgets a folder.
    func remove(_ folder: FolderReference) {
        save(folders.filter { $0 != folder })
    }

    /// Writes the list to the defaults. Encoding an array of plain values
    /// can't fail in practice, so a failure here is a programming error.
    private func save(_ folders: [FolderReference]) {
        do {
            try defaults.set(JSONEncoder().encode(folders), forKey: Self.key)
        } catch {
            preconditionFailure("Couldn't encode the open folder list: \(error)")
        }
    }
}
