import AppKit

/// The app's document controller. The controller changes two things from
/// AppKit's: the Open panel lets the user choose folders, since every
/// document is a folder, and only one Open panel shows at a time.
final class FolderDocumentController: NSDocumentController {
    /// The Open panel on screen, or nil when none is.
    private var shownOpenPanel: NSOpenPanel?

    /// Show the Open panel set to choose folders and not files. If one is
    /// already showing, bring it forward instead and cancel this request.
    /// The app shows the panel whenever it has no windows (see AppDelegate),
    /// and the panel doesn't count as one, so without this each click on
    /// the Dock icon would add another.
    override func beginOpenPanel(
        _ openPanel: NSOpenPanel,
        forTypes types: [String]?,
        completionHandler: @escaping (Int) -> Void
    ) {
        if let shownOpenPanel {
            shownOpenPanel.makeKeyAndOrderFront(nil)
            completionHandler(NSApplication.ModalResponse.cancel.rawValue)
            return
        }
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        shownOpenPanel = openPanel
        super.beginOpenPanel(openPanel, forTypes: types) { result in
            MainActor.assumeIsolated {
                self.shownOpenPanel = nil
            }
            completionHandler(result)
        }
    }
}
