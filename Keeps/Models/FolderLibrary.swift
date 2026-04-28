import Foundation
import Observation

/// Owns the photo items for a single open folder. Handles directory scanning,
/// file pairing, selection, view mode, marking, pass-based review, and state
/// persistence. Does not load image data — that's ImagePipeline's job.
@Observable
class FolderLibrary {
    enum ViewMode { case grid, single }
    enum Mark: Codable { case pick, reject }

    struct PassStats: Codable {
        let picks: Int
        let rejects: Int
    }

    struct Pass: Codable {
        let number: Int
        var photoIDs: [UUID] // var so the current pass can grow via pullToCurrentPass
        /// Frozen at commit time. Nil for the current (latest) pass.
        var committedStats: PassStats?
    }

    private(set) var folderURL: URL?
    private(set) var folderError: Error?
    private(set) var selectedItemID: UUID?
    var viewMode: ViewMode = .grid
    private(set) var items: [PhotoItem] = []
    private(set) var filteredItems: [PhotoItem] = []
    private(set) var marks: [UUID: Mark] = [:]
    private(set) var passes: [Pass] = []
    private(set) var currentPassIndex: Int = 0

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
    /// selected item identity, so the selection follows the item across pass switches.
    var selectedIndex: Int? {
        get {
            guard let id = selectedItemID else { return nil }
            return filteredItems.firstIndex { $0.id == id }
        }
        set {
            selectedItemID = newValue.map { filteredItems[$0].id }
        }
    }

    /// True when the current pass has at least one marked photo, enabling commit.
    var canAdvancePass: Bool {
        guard !passes.isEmpty else { return false }
        return passes[currentPassIndex].photoIDs.contains { marks[$0] != nil }
    }

    func setMark(_ mark: Mark?, for item: PhotoItem) {
        marks[item.id] = mark
        saveState()
    }

    /// Marks the currently selected item and advances selection to the next one.
    func applyMarkAndAdvance(_ mark: Mark?) {
        guard let index = selectedIndex else { return }
        setMark(mark, for: filteredItems[index])
        lastMarkEvent = MarkEvent(mark: mark)
        let items = filteredItems
        selectedIndex = items.isEmpty ? nil : min(items.count - 1, index + 1)
    }

    /// Creates a new pass containing only the undecided photos from the current pass.
    func advancePass() {
        let undecidedIDs = passes[currentPassIndex].photoIDs.filter { marks[$0] == nil }
        passes[currentPassIndex].committedStats = stats(for: passes[currentPassIndex])
        passes.append(Pass(number: passes.count + 1, photoIDs: undecidedIDs, committedStats: nil))
        currentPassIndex = passes.count - 1
        updateFilteredItems()
        selectedIndex = filteredItems.isEmpty ? nil : 0
        saveState()
    }

    /// Unmarks a photo and adds it to the current pass if not already present.
    func pullToCurrentPass(item: PhotoItem) {
        marks[item.id] = nil
        if !passes[currentPassIndex].photoIDs.contains(item.id) {
            passes[currentPassIndex].photoIDs.append(item.id)
        }
        updateFilteredItems()
        saveState()
    }

    func selectPass(_ index: Int) {
        currentPassIndex = index
        updateFilteredItems()
        selectedIndex = filteredItems.isEmpty ? nil : 0
    }

    func stats(for pass: Pass) -> PassStats {
        if let frozen = pass.committedStats { return frozen }
        return PassStats(
            picks: pass.photoIDs.filter { marks[$0] == .pick }.count,
            rejects: pass.photoIDs.filter { marks[$0] == .reject }.count
        )
    }

    func openFolder(url: URL) {
        folderURL = url
        folderError = nil
        viewMode = .grid
        do {
            items = try scanFolder(url: url)
        } catch {
            items = []
            passes = []
            folderError = error
            updateFilteredItems()
            return
        }

        let knownIDs = Set(items.map(\.id))
        loadState(knownIDs: knownIDs)

        if passes.isEmpty {
            passes = [Pass(number: 1, photoIDs: items.map(\.id))]
            currentPassIndex = 0
        } else {
            // Add photos added to the folder since the last session to the current pass.
            let allPassIDs = Set(passes.flatMap(\.photoIDs))
            let newIDs = items.map(\.id).filter { !allPassIDs.contains($0) }
            if !newIDs.isEmpty {
                passes[currentPassIndex].photoIDs.append(contentsOf: newIDs)
            }
        }

        updateFilteredItems()
        selectedItemID = filteredItems.first?.id
    }

    private func updateFilteredItems() {
        guard !passes.isEmpty else { filteredItems = []; return }
        let passIDs = Set(passes[currentPassIndex].photoIDs)
        filteredItems = items.filter { passIDs.contains($0.id) }
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
                PhotoItem(
                    id: UUID.forPhoto(folderURL: url, stem: stem),
                    stem: stem,
                    rawURL: rawByStem[stem],
                    jpegURL: jpegByStem[stem]
                )
            }
    }

    // MARK: - Persistence

    private var stateFileURL: URL? {
        folderURL?.appendingPathComponent("keeps.json")
    }

    private func saveState() {
        guard let url = stateFileURL else { return }
        let data = try? JSONEncoder().encode(LibraryState(marks: marks, passes: passes, currentPassIndex: currentPassIndex))
        try? data?.write(to: url)
    }

    private func loadState(knownIDs: Set<UUID>) {
        guard let url = stateFileURL,
              let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(LibraryState.self, from: data)
        else { return }

        marks = state.marks.filter { knownIDs.contains($0.key) }
        // Filter out any saved photo IDs that no longer exist in the folder.
        passes = state.passes.map { pass in
            Pass(number: pass.number, photoIDs: pass.photoIDs.filter { knownIDs.contains($0) })
        }.filter { !$0.photoIDs.isEmpty }
        currentPassIndex = min(state.currentPassIndex, max(0, passes.count - 1))
    }
}
