import AppKit
import Foundation

/// Asks the user to choose a photo folder, and turns the choice into a
/// FolderReference a window can be opened for. Does not open the window or
/// the folder itself.
@MainActor
enum FolderPicker {
    /// Shows the open panel. Returns nil if the user cancels. If the choice
    /// can't be bookmarked, explains why in an alert and returns nil.
    static func chooseFolder() -> FolderReference? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            return try FolderReference.make(for: url)
        } catch {
            NSAlert(error: error).runModal()
            return nil
        }
    }
}
