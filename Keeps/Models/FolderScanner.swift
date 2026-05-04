import Foundation

/// Scans a folder and produces the list of photos found inside, pairing RAW
/// and JPEG files that share a filename stem and sorting the result by file
/// creation date. Pure file-system reader: does not load image data, mutate
/// any state, or know anything about the rest of the library.
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
        let (rawByStem, jpegByStem) = pairFilesByType(urls: urls)
        return buildSortedItems(rawByStem: rawByStem, jpegByStem: jpegByStem)
    }

    /// Groups URLs into RAW and JPEG dictionaries keyed by filename stem.
    /// Files with unsupported extensions are dropped.
    private static func pairFilesByType(
        urls: [URL]
    ) -> (rawByStem: [String: URL], jpegByStem: [String: URL]) {
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

        return (rawByStem, jpegByStem)
    }

    /// Builds PhotoItems from paired file dictionaries, sorted by creation date.
    private static func buildSortedItems(
        rawByStem: [String: URL],
        jpegByStem: [String: URL]
    ) -> [PhotoItem] {
        let allStems = Set(rawByStem.keys).union(jpegByStem.keys)
        return allStems
            .map { stem -> PhotoItem in
                // stem is in allStems (the union), so it must be in rawByStem if not jpegByStem.
                // swiftlint:disable:next force_unwrapping
                let sourceURL = jpegByStem[stem] ?? rawByStem[stem]!
                return PhotoItem(
                    id: UUID(),
                    stem: stem,
                    rawURL: rawByStem[stem],
                    jpegURL: jpegByStem[stem],
                    capturedAt: creationDate(of: sourceURL)
                )
            }
            .sorted { $0.capturedAt < $1.capturedAt }
    }

    private static func creationDate(of url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
            ?? Date(timeIntervalSince1970: 0)
    }
}
