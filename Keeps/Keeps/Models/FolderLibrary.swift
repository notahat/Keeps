import Foundation
import Observation

/// Owns the photo items for a single open folder. Handles directory scanning,
/// file pairing, selection, view mode, marking, and filter state. Does not load
/// image data — that's ImageLoader's job.
@Observable
class FolderLibrary {
    enum ViewMode { case grid, single }
    enum Mark { case pick, reject }
    enum FilterMode { case all, picked, rejected, unmarked }

    private(set) var items: [PhotoItem] = []
    private(set) var folderURL: URL?
    var selectedIndex: Int?
    var viewMode: ViewMode = .grid
    private(set) var marks: [UUID: Mark] = [:]
    private(set) var filterMode: FilterMode = .all

    var filteredItems: [PhotoItem] {
        switch filterMode {
        case .all:      return items
        case .picked:   return items.filter { marks[$0.id] == .pick }
        case .rejected: return items.filter { marks[$0.id] == .reject }
        case .unmarked: return items.filter { marks[$0.id] == nil }
        }
    }

    func setMark(_ mark: Mark?, for item: PhotoItem) {
        marks[item.id] = mark
        clampSelectedIndex()
    }

    func applyFilter(_ mode: FilterMode) {
        filterMode = mode
        selectedIndex = filteredItems.isEmpty ? nil : 0
    }

    func openFolder(url: URL) {
        folderURL = url
        items = scanFolder(url: url)
        selectedIndex = items.isEmpty ? nil : 0
    }

    private func clampSelectedIndex() {
        guard let index = selectedIndex else { return }
        selectedIndex = filteredItems.isEmpty ? nil : min(index, filteredItems.count - 1)
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
