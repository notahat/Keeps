import Foundation
import Observation

/// Owns the photo items for a single open folder. Handles directory scanning,
/// file pairing, selection, view mode, marking, pass-based review, and state
/// persistence. Does not load image data — that's ImagePipeline's job.
///
/// Each pass stores its own picks and rejects. The photos visible in pass N are
/// all photos not picked or rejected in passes 0..<N, so marks made in earlier
/// passes automatically hide those photos from later ones.
@Observable
class FolderLibrary {
    enum ViewMode { case grid, single }
    enum Mark: String, Codable { case pick, reject }
    enum FilterMode { case all, picked, rejected, unmarked }

    struct PassStats {
        let total: Int
        let picks: Int
        let rejects: Int
    }

    struct Pass {
        var picks: Set<UUID> = []
        var rejects: Set<UUID> = []
    }

    private(set) var folderURL: URL?
    private(set) var folderError: Error?
    private(set) var selectedItemID: UUID?
    var viewMode: ViewMode = .grid
    var filterMode: FilterMode = .all
    private(set) var items: [PhotoItem] = []
    private(set) var filteredItems: [PhotoItem] = []
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

    private var currentPass: Pass? {
        passes.isEmpty ? nil : passes[currentPassIndex]
    }

    private var currentPassPhotoIDs: Set<UUID> {
        let previouslyMarked = passes[0 ..< currentPassIndex].reduce(into: Set<UUID>()) {
            $0.formUnion($1.picks)
            $0.formUnion($1.rejects)
        }
        return Set(items.map(\.id)).subtracting(previouslyMarked)
    }

    /// Returns the mark for a photo in the currently viewed pass, or nil if unmarked.
    func mark(for id: UUID) -> Mark? {
        guard let currentPass else { return nil }
        if currentPass.picks.contains(id) { return .pick }
        if currentPass.rejects.contains(id) { return .reject }
        return nil
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

    /// True when the last pass has at least one marked photo, enabling commit.
    var canAdvancePass: Bool {
        guard let pass = passes.last else { return false }
        return !pass.picks.isEmpty || !pass.rejects.isEmpty
    }

    func setMark(_ mark: Mark?, for item: PhotoItem) {
        passes[currentPassIndex].picks.remove(item.id)
        passes[currentPassIndex].rejects.remove(item.id)
        if mark == .pick { passes[currentPassIndex].picks.insert(item.id) }
        else if mark == .reject { passes[currentPassIndex].rejects.insert(item.id) }
        if filterMode != .all { updateFilteredItems() }
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

    /// Creates a new pass. Photos not marked in the current pass will appear in it.
    func advancePass() {
        passes.append(Pass())
        currentPassIndex = passes.count - 1
        updateFilteredItems()
        selectedIndex = filteredItems.isEmpty ? nil : 0
        saveState()
    }

    func applyFilter(_ mode: FilterMode) {
        filterMode = mode
        updateFilteredItems()
        selectedIndex = filteredItems.isEmpty ? nil : 0
    }

    func selectPass(_ index: Int) {
        currentPassIndex = index
        filterMode = .all
        updateFilteredItems()
        selectedIndex = filteredItems.isEmpty ? nil : 0
    }

    func stats(for index: Int) -> PassStats {
        let markedInPreviousPasses = passes[0 ..< index].reduce(into: Set<UUID>()) {
            $0.formUnion($1.picks)
            $0.formUnion($1.rejects)
        }
        return PassStats(
            total: items.filter { !markedInPreviousPasses.contains($0.id) }.count,
            picks: passes[index].picks.count,
            rejects: passes[index].rejects.count
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

        loadState(knownItems: items)

        if passes.isEmpty {
            passes = [Pass()]
            currentPassIndex = 0
        }

        updateFilteredItems()
        selectedItemID = filteredItems.first?.id
    }

    private func updateFilteredItems() {
        guard let currentPass else { filteredItems = []; return }
        let visibleIDs = switch filterMode {
        case .all: currentPassPhotoIDs
        case .picked: currentPass.picks
        case .rejected: currentPass.rejects
        case .unmarked: currentPassPhotoIDs.subtracting(currentPass.picks).subtracting(currentPass.rejects)
        }
        filteredItems = items.filter { visibleIDs.contains($0.id) }
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
                    id: UUID(),
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
        let stemByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.stem) })
        let state = LibraryState(
            passes: passes.map { pass in
                LibraryState.Pass(
                    picks: pass.picks.compactMap { stemByID[$0] }.sorted(),
                    rejects: pass.rejects.compactMap { stemByID[$0] }.sorted()
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try? encoder.encode(state)
        try? data?.write(to: url)
    }

    private func loadState(knownItems: [PhotoItem]) {
        guard let url = stateFileURL,
              let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(LibraryState.self, from: data)
        else { return }

        let idByStem = Dictionary(uniqueKeysWithValues: knownItems.map { ($0.stem, $0.id) })
        passes = state.passes.map { savedPass in
            Pass(
                picks: Set(savedPass.picks.compactMap { idByStem[$0] }),
                rejects: Set(savedPass.rejects.compactMap { idByStem[$0] })
            )
        }
        currentPassIndex = max(0, passes.count - 1)
    }
}
