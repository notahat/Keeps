import Foundation

/// Scans a folder and produces the list of photos found inside, pairing RAW
/// and JPEG files that share a filename stem and sorting the result by file
/// creation date. It only reads the file system: it doesn't load image
/// data, change any state, or know anything about the rest of the app.
enum FolderScanner {
    private static let rawExtensions: Set<String> = [
        "cr2", "cr3", "nef", "arw", "dng", "raf", "orf", "rw2", "rw1", "3fr",
    ]
    private static let jpegExtensions: Set<String> = ["jpg", "jpeg"]

    /// Scans the folder for RAW and JPEG files and returns the resulting
    /// PhotoItems in chronological order. Throws if the folder cannot be read.
    static func scan(url: URL) throws -> [PhotoItem] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: .skipsHiddenFiles
        )
        let (rawByStem, jpegByStem) = splitFilesByType(urls: urls)
        return buildSortedItems(rawByStem: rawByStem, jpegByStem: jpegByStem)
    }

    /// Splits the files into RAW and JPEG dictionaries keyed by filename
    /// stem. Files with unsupported extensions are dropped.
    private static func splitFilesByType(
        urls: [URL]
    ) -> (rawByStem: [String: URL], jpegByStem: [String: URL]) {
        var rawByStem: [String: URL] = [:]
        var jpegByStem: [String: URL] = [:]

        for fileURL in urls {
            let fileExtension = fileURL.pathExtension.lowercased()
            let stem = fileURL.deletingPathExtension().lastPathComponent
            if rawExtensions.contains(fileExtension) {
                rawByStem[stem] = fileURL
            } else if jpegExtensions.contains(fileExtension) {
                jpegByStem[stem] = fileURL
            }
        }

        return (rawByStem, jpegByStem)
    }

    /// Builds a PhotoItem for each stem, pairing its RAW and JPEG files when
    /// it has both, and sorts them by creation date.
    private static func buildSortedItems(
        rawByStem: [String: URL],
        jpegByStem: [String: URL]
    ) -> [PhotoItem] {
        let allStems = Set(rawByStem.keys).union(jpegByStem.keys)
        return allStems
            .map { stem -> PhotoItem in
                // Every stem came from one dictionary or the other, so it's in
                // rawByStem whenever it isn't in jpegByStem.
                // swiftlint:disable:next force_unwrapping
                let sourceURL = jpegByStem[stem] ?? rawByStem[stem]!
                return PhotoItem(
                    id: UUID(),
                    stem: stem,
                    rawURL: rawByStem[stem],
                    jpegURL: jpegByStem[stem],
                    fileCreationDate: creationDate(of: sourceURL)
                )
            }
            .sorted { $0.fileCreationDate < $1.fileCreationDate }
    }

    /// The file's creation date, or the start of 1970 when it can't be read,
    /// so such files sort first.
    private static func creationDate(of url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
            ?? Date(timeIntervalSince1970: 0)
    }
}
