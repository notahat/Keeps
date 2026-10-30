import AppKit
import SwiftUI

/// Makes and runs one folder's window, which hosts FolderView. The document
/// gives the window its title and its title-bar folder icon; this adds the
/// folder's path as the subtitle.
final class FolderWindowController: NSWindowController {
    private static let defaultContentSize = NSSize(width: 1000, height: 700)

    /// Makes the window for an open folder session.
    init(session: FolderSession) {
        let hostingController = NSHostingController(rootView: FolderView(session: session))
        // Lets the workflow's SwiftUI toolbar items show in the window's
        // toolbar.
        hostingController.sceneBridgingOptions = [.toolbars]
        let window = NSWindow(contentViewController: hostingController)
        window.toolbar = Self.makePlaceholderToolbar()
        window.toolbarStyle = .unified
        window.setContentSize(Self.defaultContentSize)
        window.subtitle = session.folderURL.path
        window.appearance = NSAppearance(named: .darkAqua)
        super.init(window: window)
    }

    /// Makes an empty toolbar matching the one SwiftUI makes for the
    /// workflow's toolbar items, which replaces it when there are any. This
    /// gives a folder with no photos, and so no workflow, the same title bar
    /// as one with photos.
    private static func makePlaceholderToolbar() -> NSToolbar {
        let toolbar = NSToolbar()
        toolbar.displayMode = .iconOnly
        return toolbar
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not used")
    }
}
