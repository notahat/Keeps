import Foundation
import Observation

/// Owns the photo items for a single open folder. Handles directory scanning and
/// file pairing. Does not load image data — that's ImageLoader's job.
@Observable
class FolderLibrary {
    private(set) var items: [PhotoItem] = []
    private(set) var folderURL: URL?

    func openFolder(url: URL) {
        folderURL = url
        items = scanFolder(url: url)
    }

    private func scanFolder(url: URL) -> [PhotoItem] {
        let rawExtensions: Set<String> = ["cr2", "cr3", "nef", "arw", "dng", "raf", "orf", "rw2", "rw1", "3fr"]
        let jpegExtensions: Set<String> = ["jpg", "jpeg"]

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        var rawByStem: [String: URL] = [:]
        var jpegByStem: [String: URL] = [:]

        for fileURL in urls {
            let ext = fileURL.pathExtension.lowercased()
            let stem = fileURL.deletingPathExtension().lastPathComponent
            if rawExtensions.contains(ext) {
                rawByStem[stem] = fileURL
            } else if jpegExtensions.contains(ext) {
                jpegByStem[stem] = fileURL
            }
        }

        let allStems = Set(rawByStem.keys).union(jpegByStem.keys)
        return allStems
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { stem in
                PhotoItem(id: UUID(), stem: stem, rawURL: rawByStem[stem], jpegURL: jpegByStem[stem])
            }
    }
}
