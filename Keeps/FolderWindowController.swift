import AppKit
import SwiftUI

/// Makes and runs one folder's window, which hosts FolderView. The document
/// gives the window its title and its title-bar folder icon; this adds the
/// folder's path as the subtitle, and keeps the window's frame in the
/// folder's keeps.json: the saved frame is applied before the window first
/// shows, and moves and resizes are saved. Full-screen frames aren't saved,
/// so a window left in full screen reopens at its ordinary size.
final class FolderWindowController: NSWindowController, NSWindowDelegate {
    private static let defaultContentSize = NSSize(width: 1000, height: 700)

    private let folderURL: URL

    /// Makes the window for an open folder session, at the folder's saved
    /// frame if it has one.
    init(session: FolderSession) {
        folderURL = session.folderURL
        let window = Self.makeWindow(session: session)
        super.init(window: window)
        if let savedFrame = WindowFrameStore.savedFrame(in: folderURL) {
            window.setFrame(savedFrame, display: false)
            // Cascading would move the window off its saved position.
            shouldCascadeWindows = false
        }
        // Set last, so applying the saved frame doesn't save it again.
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// Saves the frame after the user moves the window.
    func windowDidMove(_: Notification) {
        saveFrame()
    }

    /// Saves the frame after a resize, except during a live resize, which
    /// is saved once when it ends.
    func windowDidResize(_: Notification) {
        guard window?.inLiveResize == false else { return }
        saveFrame()
    }

    /// Saves the frame when the user finishes resizing the window.
    func windowDidEndLiveResize(_: Notification) {
        saveFrame()
    }

    /// Saves the window's frame unless it's full screen, and shows an alert
    /// on the window if that fails.
    private func saveFrame() {
        guard let window, !window.styleMask.contains(.fullScreen) else { return }
        do {
            try WindowFrameStore.save(window.frame, in: folderURL)
        } catch {
            window.presentError(error, modalFor: window, delegate: nil,
                                didPresent: nil, contextInfo: nil)
        }
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
