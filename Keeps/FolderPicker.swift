import AppKit
import Foundation

/// Turns a folder the user has chosen, from the open panel or elsewhere,
/// into a FolderReference a window can be opened for. Does not open the
/// window or the folder itself.
@MainActor
enum FolderPicker {
    /// Shows the open panel. Returns nil if the user cancels, or if the
    /// choice can't be bookmarked.
    static func chooseFolder() -> FolderReference? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return reference(for: url)
    }

    /// Makes a reference to a folder the app has just been given access to.
    /// If it can't be bookmarked, explains why in an alert and returns nil.
    static func reference(for url: URL) -> FolderReference? {
        do {
            return try FolderReference.make(for: url)
        } catch {
            NSAlert(error: error).runModal()
            return nil
        }
    }
}
