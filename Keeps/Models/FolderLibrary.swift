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

    private(set) var folderURL: URL?
    private(set) var folderError: Error?
    private(set) var selectedItemID: UUID?
    var viewMode: ViewMode = .grid
    private(set) var filterMode: FilterMode = .all
    private(set) var items: [PhotoItem] = []
    private(set) var filteredItems: [PhotoItem] = []
    private(set) var marks: [UUID: Mark] = [:]

    /// Set each time applyMarkAndAdvance is called, so observers can react to
    /// mark actions regardless of which code path triggered them.
    private(set) var lastMarkEvent: MarkEvent?

    /// Uniquely identifies a single mark application, so observers can detect
    /// repeated applications of the same mark value.
    struct MarkEvent: Equatable {
        let mark: Mark?
        private let token = UUID()

        static func == (lhs: MarkEvent, rhs: MarkEvent) -> Bool {
            lhs.token == rhs.token
        }
    }

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

    func setMark(_ mark: Mark?, for item: PhotoItem) {
        marks[item.id] = mark
        updateFilteredItems()
    }

    /// Marks the currently selected item and advances selection to the next one.
    func applyMarkAndAdvance(_ mark: Mark?) {
        guard let index = selectedIndex else { return }
        setMark(mark, for: filteredItems[index])
        lastMarkEvent = MarkEvent(mark: mark)
        let items = filteredItems
        selectedIndex = items.isEmpty ? nil : min(items.count - 1, index + 1)
    }

    func applyFilter(_ mode: FilterMode) {
        filterMode = mode
        updateFilteredItems()
    }

    private func updateFilteredItems() {
        filteredItems = switch filterMode {
        case .all: items
        case .picked: items.filter { marks[$0.id] == .pick }
        case .rejected: items.filter { marks[$0.id] == .reject }
        case .unmarked: items.filter { marks[$0.id] == nil }
        }
    }

    func openFolder(url: URL) {
        folderURL = url
        folderError = nil
        do {
            items = try scanFolder(url: url)
        } catch {
            items = []
            folderError = error
        }
        updateFilteredItems()
        selectedItemID = items.first?.id
    }

    private func scanFolder(url: URL) throws -> [PhotoItem] {
        let rawExtensions: Set = ["cr2", "cr3", "nef", "arw", "dng", "raf", "orf", "rw2", "rw1", "3fr"]
        let jpegExtensions: Set = ["jpg", "jpeg"]

        let urls = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: .skipsHiddenFiles
        )

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
