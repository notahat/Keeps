import AppKit
import SwiftUI

/// Top-level view. Routes between the grid and single-image views as the library
/// state changes.
struct ContentView: View {
    @State private var library = FolderLibrary()
    @State private var persistence: LibraryPersistence?

    @State private var showingSortConfirmation = false
    @State private var showingSortComplete = false
    @State private var sortError: String?

    private enum DisplayState { case empty, error(Error), grid, single }

    private var displayState: DisplayState {
        if let error = library.folderError { return .error(error) }
        if library.items.isEmpty { return .empty }
        return library.viewMode == .single ? .single : .grid
    }

    var body: some View {
        NavigationSplitView {
            PassSidebarView(library: library)
        } detail: {
            Group {
                switch displayState {
                case .empty: emptyState
                case let .error(error): errorState(error)
                case .grid: GridView(library: library)
                case .single: SingleImageView(library: library)
                }
            }
            .focusedSceneValue(\.library, library)
            .focusedSceneValue(\.openFolderAction) { openFolder() }
            .focusedSceneValue(\.sortPhotosAction, library.items.isEmpty ? nil : {
                showingSortConfirmation = true
            })
            .navigationTitle(library.folderURL?.lastPathComponent ?? "Keeps")
            .navigationSubtitle(library.folderURL?.path ?? "")
            .toolbar { toolbar }
        }
        .frame(minWidth: 500, minHeight: 300)
        .preferredColorScheme(.dark)
        .modifier(SortDialogs(
            showingConfirmation: $showingSortConfirmation,
            showingComplete: $showingSortComplete,
            error: Binding(
                get: { sortError },
                set: { sortError = $0 }
            ),
            onSort: performSort,
            onDismissComplete: closeFolder
        ))
        .onAppear {
            restoreLastFolder()
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(action: openFolder) {
                Image(systemName: "folder")
            }
            .help("Open Folder")
        }

        ToolbarItem(placement: .principal) {
            Picker("Filter", selection: Binding(
                get: { FilterOption(library.filterMode) },
                set: { option in
                    switch option {
                    case .all: library.applyFilter(.all)
                    case .picked: library.applyFilter(.picked)
                    case .rejected: library.applyFilter(.rejected)
                    case .unmarked: library.applyFilter(.unmarked)
                    case .group: library.focusSelectedItemGroup()
                    }
                }
            )) {
                Text("All").tag(FilterOption.all)
                Text("Picked").tag(FilterOption.picked)
                Text("Rejected").tag(FilterOption.rejected)
                Text("Unmarked").tag(FilterOption.unmarked)
                groupFilterLabel.tag(FilterOption.group)
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }

        ToolbarItem(placement: .status) {
            HStack(spacing: 8) {
                LoadGraphView()
                HStack(spacing: 3) {
                    Text("\(library.filteredItems.count)")
                        .monospacedDigit()
                        .frame(minWidth: 28, alignment: .trailing)
                    Text("photos")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.leading, 4)
            .padding(.trailing, 12)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            ControlGroup {
                MarkButton(markAction: .reject, isEnabled: library.selectedIndex != nil) {
                    applyMark(.reject)
                }
                MarkButton(markAction: .unmark, isEnabled: library.selectedIndex != nil) {
                    applyMark(nil)
                }
                MarkButton(markAction: .pick, isEnabled: library.selectedIndex != nil) {
                    applyMark(.pick)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("Open a folder of photos to get started")
                .foregroundStyle(.secondary)
            Button("Open Folder...", action: openFolder)
        }
    }

    private func errorState(_ error: Error) -> some View {
        VStack(spacing: 8) {
            Text("Couldn't read folder")
                .font(.headline)
            Text(error.localizedDescription)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        saveBookmark(for: url)
        startSession(for: url)
    }

    private func restoreLastFolder() {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return }

        if isStale { saveBookmark(for: url) }
        startSession(for: url)
    }

    private func startSession(for url: URL) {
        persistence?.stop()
        library.openFolder(url: url)
        let newPersistence = LibraryPersistence(folderURL: url)
        newPersistence.restore(into: library)
        newPersistence.startObserving(library)
        persistence = newPersistence
        ImagePipeline.shared.prefetchImages(for: library.items, size: ThumbnailView.imageSize)
    }

    private func saveBookmark(for url: URL) {
        let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: Self.bookmarkKey)
    }

    private func performSort() {
        guard let folderURL = library.folderURL else { return }
        let plan = library.sortPlan()
        let moves = PhotoSorter.plannedMoves(folderURL: folderURL, sortPlan: plan)
        do {
            try PhotoSorter.execute(folderURL: folderURL, moves: moves)
            persistence?.stop()
            try PhotoSorter.deleteKeepsJSON(in: folderURL)
            showingSortComplete = true
        } catch {
            sortError = error.localizedDescription
        }
    }

    private func closeFolder() {
        persistence?.stop()
        persistence = nil
        library.close()
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
    }

    private func applyMark(_ mark: FolderLibrary.Mark?) {
        library.applyMarkAndAdvance(mark)
    }

    private var groupFilterLabel: some View {
        HStack(spacing: 4) {
            if let color = library.focusedGroupColor {
                Circle().fill(color).frame(width: 8, height: 8)
            }
            Text("Group")
        }
    }

    private static let bookmarkKey = "lastFolderBookmark"
}

private enum FilterOption: Equatable, Hashable {
    case all, picked, rejected, unmarked, group

    init(_ filterMode: FolderLibrary.FilterMode) {
        switch filterMode {
        case .all: self = .all
        case .picked: self = .picked
        case .rejected: self = .rejected
        case .unmarked: self = .unmarked
        case .group: self = .group
        }
    }
}

/// Bundles the confirmation dialog, success alert, and error alert for the
/// sort-photos-into-folders action.
private struct SortDialogs: ViewModifier {
    @Binding var showingConfirmation: Bool
    @Binding var showingComplete: Bool
    @Binding var error: String?
    var onSort: () -> Void
    var onDismissComplete: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Sort Photos into Folders?",
                isPresented: $showingConfirmation
            ) {
                Button("Sort", role: .destructive) { onSort() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will move all photos into Picked, Rejected, and Undecided folders and close the current session. This cannot be undone from within Keeps.")
            }
            .alert("Sorting Complete", isPresented: $showingComplete) {
                Button("OK") { onDismissComplete() }
            } message: {
                Text("Photos have been sorted into folders.")
            }
            .alert("Sorting Failed", isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK") {}
            } message: {
                if let error {
                    Text(error)
                }
            }
    }
}

#Preview {
    ContentView()
}
