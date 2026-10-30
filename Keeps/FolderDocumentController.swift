import AppKit

/// The app's document controller. Its only change from AppKit's is that the
/// Open panel chooses folders, since every document is a folder.
final class FolderDocumentController: NSDocumentController {
    /// Sets the Open panel to choose folders and not files, then shows it.
    override func beginOpenPanel(
        _ openPanel: NSOpenPanel,
        forTypes types: [String]?,
        completionHandler: @escaping (Int) -> Void
    ) {
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        super.beginOpenPanel(openPanel, forTypes: types, completionHandler: completionHandler)
    }
}
