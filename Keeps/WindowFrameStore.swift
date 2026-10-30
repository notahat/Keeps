import CoreGraphics
import Foundation

/// Reads and writes a folder window's frame in the folder's keeps.json, so
/// the window reopens where it was. Deciding when to save is the window
/// controller's job.
nonisolated enum WindowFrameStore {
    private static let frameKey = "windowFrame"

    /// The frame saved for the folder's window, or nil if none is saved or
    /// keeps.json can't be read.
    static func savedFrame(in folderURL: URL) -> CGRect? {
        KeepsFile(folderURL: folderURL).read(CGRect.self, forKey: frameKey)
    }

    /// Saves the frame for the folder's window, keeping everything else in
    /// keeps.json. Throws if the file can't be written.
    static func save(_ frame: CGRect, in folderURL: URL) throws {
        try KeepsFile(folderURL: folderURL).write([frameKey: frame])
    }
}
