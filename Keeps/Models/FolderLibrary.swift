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
    private(set) var selectedItemID: UUID?
    var viewMode: ViewMode = .grid
    private(set) var marks: [UUID: Mark] = [:]
    private(set) var filterMode: FilterMode = .all

    /// The index of the selected item within the current filtered list, or nil if the
    /// selected item isn't present in the current filter. Setting this updates the
    /// selected item identity, so the selection follows the item across filter switches.
    var selectedIndex: Int? {
        get {
            guard let id = selectedItemID else { return nil }
            return filteredItems.firstIndex { $0.id == id }
        }
        set {
            selectedItemID = newValue.map { filteredItems[$0].id }
        }
    }

    var filteredItems: [PhotoItem] {
        switch filterMode {
        case .all: items
        case .picked: items.filter { marks[$0.id] == .pick }
        case .rejected: items.filter { marks[$0.id] == .reject }
        case .unmarked: items.filter { marks[$0.id] == nil }
        }
    }

    func setMark(_ mark: Mark?, for item: PhotoItem) {
        marks[item.id] = mark
    }

    func applyFilter(_ mode: FilterMode) {
        filterMode = mode
    }

    func openFolder(url: URL) {
        folderURL = url
        items = scanFolder(url: url)
        selectedItemID = items.first?.id
    }

    private func scanFolder(url: URL) -> [PhotoItem] {
        let rawExtensions: Set = ["cr2", "cr3", "nef", "arw", "dng", "raf", "orf", "rw2", "rw1", "3fr"]
        let jpegExtensions: Set = ["jpg", "jpeg"]

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
