import AppKit

/// Shows the Open panel where AppKit would otherwise make an untitled
/// document: at launch with nothing to restore, and on a Dock click with no
/// windows open. A folder can't be untitled, so choosing one is the closest
/// equivalent. Everything else about documents is left to AppKit.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Let AppKit ask for an untitled document, so that it calls
    /// applicationOpenUntitledFile at the usual moments.
    func applicationShouldOpenUntitledFile(_: NSApplication) -> Bool {
        true
    }

    /// Show the Open panel in place of an untitled document.
    func applicationOpenUntitledFile(_: NSApplication) -> Bool {
        NSDocumentController.shared.openDocument(nil)
        return true
    }
}
