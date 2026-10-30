import AppKit
import SwiftUI

/// Makes one folder's window, which hosts FolderView. The document gives the
/// window its title and its title-bar folder icon; this adds the folder's
/// path as the subtitle. AppKit saves the window's frame in the app's
/// preferences under the folder's path, so a folder reopens where its window
/// was last left.
final class FolderWindowController: NSWindowController {
    private static let defaultContentSize = NSSize(width: 1000, height: 700)

    /// Makes the window for an open folder session, at the folder's saved
    /// frame if it has one.
    init(session: FolderSession) {
        super.init(window: Self.makeWindow(session: session))
        windowFrameAutosaveName = session.folderURL.path
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// Makes the window hosting the folder's view, at the default size.
    private static func makeWindow(session: FolderSession) -> NSWindow {
        let hostingController = NSHostingController(rootView: FolderView(session: session))
        // Lets the workflow's SwiftUI toolbar items show in the window's
        // toolbar.
        hostingController.sceneBridgingOptions = [.toolbars]
        let window = NSWindow(contentViewController: hostingController)
        window.toolbar = makePlaceholderToolbar()
        window.toolbarStyle = .unified
        window.setContentSize(defaultContentSize)
        window.subtitle = session.folderURL.path
        window.appearance = NSAppearance(named: .darkAqua)
        return window
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
}
