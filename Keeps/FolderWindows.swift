import AppKit

/// Finds the window already showing a folder and brings it forward.
/// SwiftUI's openWindow doesn't reliably match a newly made FolderReference
/// to the window showing the same folder, so this goes by the folder each
/// window shows as its document (see ContentView's navigationDocument).
@MainActor
enum FolderWindows {
    /// Brings forward the window showing the folder. Returns false if no
    /// window is showing it.
    static func bringForward(_ folder: FolderReference) -> Bool {
        let showing = NSApplication.shared.windows.first { window in
            guard let shownURL = window.representedURL else { return false }
            return folder.names(shownURL)
        }
        guard let showing else { return false }
        showing.makeKeyAndOrderFront(nil)
        return true
    }
}
