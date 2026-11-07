import AppKit

/// One open photo folder as an AppKit document. Opening the document opens
/// the folder's session; AppKit handles everything around that: the Open
/// panel, Open Recent, folders dropped on the Dock icon, bringing forward a
/// folder that's already open, and reporting a folder that can't be read.
///
/// The document is never saved and never autosaves. The grouping is
/// written to the folder's keeps.json as it changes.
final class FolderDocument: NSDocument {
    /// The open folder, or nil until AppKit has read it.
    private var session: FolderSession?

    /// Turns off autosaving, since there's nothing for AppKit to save.
    override nonisolated class var autosavesInPlace: Bool {
        false
    }

    /// Open the folder's session, in place of AppKit's default reading,
    /// which would load the whole folder into a file wrapper. Throw when the
    /// folder can't be read, which AppKit reports to the user.
    override nonisolated func read(from url: URL, ofType _: String) throws {
        // AppKit reads documents on the main thread unless the class opts in
        // to concurrent reading, which this one doesn't.
        try MainActor.assumeIsolated {
            session = try FolderSession(folderURL: url)
        }
    }

    /// Make the folder's window.
    override func makeWindowControllers() {
        guard let session else {
            preconditionFailure("A folder document makes its window only after reading the folder")
        }
        addWindowController(FolderWindowController(session: session))
    }
}
