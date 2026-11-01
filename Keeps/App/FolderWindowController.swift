import AppKit
import SwiftUI

/// Makes one folder's window, which hosts FolderView. The document gives the
/// window its title and its title-bar folder icon; this adds the section
/// showing to the title, such as "Holiday — To go", so the window always
/// says where you are, and the folder's path as the subtitle. AppKit saves
/// the window's frame in the app's preferences under the folder's path, so a
/// folder reopens where its window was last left.
final class FolderWindowController: NSWindowController {
    private static let defaultContentSize = NSSize(width: 1000, height: 700)

    /// The section FolderView last reported showing, for the title.
    private var section: FolderSection?

    /// Makes the window for an open folder session, at the folder's saved
    /// frame if it has one.
    init(session: FolderSession) {
        super.init(window: nil)
        window = makeWindow(session: session)
        windowFrameAutosaveName = session.folderURL.path
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// The document's name, followed by the section showing once known.
    override func windowTitle(forDocumentDisplayName displayName: String) -> String {
        guard let section else { return displayName }
        return "\(displayName) — \(section.title)"
    }

    /// Records the section showing and retitles the window to match.
    private func show(_ newSection: FolderSection) {
        section = newSection
        synchronizeWindowTitleWithDocumentName()
    }

    /// Makes the window hosting the folder's view, at the default size.
    private func makeWindow(session: FolderSession) -> NSWindow {
        let folderView = FolderView(session: session) { [weak self] section in
            self?.show(section)
        }
        let hostingController = NSHostingController(rootView: folderView)
        // Lets the folder view's SwiftUI toolbar items show in the window's
        // toolbar.
        hostingController.sceneBridgingOptions = [.toolbars]
        let window = NSWindow(contentViewController: hostingController)
        // Lets content scroll up under the toolbar and show through it, as
        // in SwiftUI's own windows. SwiftUI keeps the content's resting
        // position below the toolbar.
        window.styleMask.insert(.fullSizeContentView)
        window.toolbar = Self.makePlaceholderToolbar()
        window.toolbarStyle = .unified
        window.setContentSize(Self.defaultContentSize)
        window.subtitle = session.folderURL.path
        window.appearance = NSAppearance(named: .darkAqua)
        return window
    }

    /// Makes an empty toolbar matching the one SwiftUI makes for the
    /// folder view's toolbar items, which replaces it when there are any.
    /// This gives a folder with no photos, and so no toolbar items, the same
    /// title bar as one with photos.
    private static func makePlaceholderToolbar() -> NSToolbar {
        let toolbar = NSToolbar()
        toolbar.displayMode = .iconOnly
        return toolbar
    }
}
