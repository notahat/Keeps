import AppKit
import SwiftUI

/// Top-level view. Opens folders, owns the folder session and library, and
/// routes between the grid and single-image views as the library state
/// changes.
struct ContentView: View {
    @State private var session: FolderSession?
    @State private var library: FolderLibrary?
    @State private var folderError: Error?
    @State private var persistence: WorkflowPersistence<SimpleCullState>?

    @State private var showingSortConfirmation = false
    @State private var showingSortComplete = false
    @State private var sortError: String?

    private enum DisplayState { case empty, error(Error), grid(FolderLibrary), single(FolderLibrary) }

    private var displayState: DisplayState {
        if let folderError {
            return .error(folderError)
        }
        guard let library, !library.items.isEmpty else {
            return .empty
        }
        return library.viewMode == .single ? .single(library) : .grid(library)
    }

    var body: some View {
        Group {
            switch displayState {
            case .empty: emptyState
            case let .error(error): errorState(error)
            case let .grid(library): SimpleCullGridScreen(library: library)
            case let .single(library): SingleImageView(library: library)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusedSceneValue(\.library, library)
        .focusedSceneValue(\.openFolderAction) { openFolder() }
        .focusedSceneValue(\.sortPhotosAction, library?.items.isEmpty != false ? nil : {
            showingSortConfirmation = true
        })
        .navigationTitle(session?.folderURL.lastPathComponent ?? "Keeps")
        .navigationSubtitle(session?.folderURL.path ?? "")
        .toolbar { toolbar }
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
        .alert("Couldn't Save Changes", isPresented: Binding(
            get: { library?.saveError != nil },
            set: {
                if !$0 {
                    library?.clearSaveError()
                }
            }
        )) {
            Button("OK") {}
        } message: {
            if let error = library?.saveError {
                Text(error.localizedDescription)
            }
        }
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

        if let library {
            ToolbarItem(placement: .principal) {
                Picker("Filter", selection: Binding(
                    get: { library.filterMode },
                    set: { library.applyFilter($0) }
                )) {
                    Text("All").tag(FolderLibrary.FilterMode.all)
                    Text("Picked").tag(FolderLibrary.FilterMode.picked)
                    Text("Rejected").tag(FolderLibrary.FilterMode.rejected)
                    Text("Unmarked").tag(FolderLibrary.FilterMode.unmarked)
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
                        library.applyMarkAndAdvance(.reject)
                    }
                    MarkButton(markAction: .unmark, isEnabled: library.selectedIndex != nil) {
                        library.applyMarkAndAdvance(nil)
                    }
                    MarkButton(markAction: .pick, isEnabled: library.selectedIndex != nil) {
                        library.applyMarkAndAdvance(.pick)
                    }
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

        if isStale {
            saveBookmark(for: url)
        }
        startSession(for: url)
    }

    private func startSession(for url: URL) {
        persistence?.stop()
        persistence = nil
        folderError = nil
        do {
            let newSession = try FolderSession(folderURL: url)
            let newLibrary = FolderLibrary(items: newSession.items)
            let newPersistence = WorkflowPersistence<SimpleCullState>(
                folderURL: url,
                workflowName: SimpleCullState.workflowName
            )
            if let state = newPersistence.restore() {
                newLibrary.applyRestored(state: state)
            }
            newPersistence.startObserving(
                read: { _ = newLibrary.snapshotState() },
                snapshot: { newLibrary.snapshotState() },
                onSaveError: { newLibrary.recordSaveError($0) }
            )
            session = newSession
            library = newLibrary
            persistence = newPersistence
            ImagePipeline.shared.prefetchImages(for: newSession.items, size: ThumbnailImage.imageSize)
        } catch {
            session = nil
            library = nil
            folderError = error
        }
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
        guard let session, let library else { return }
        let folderURL = session.folderURL
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
        library = nil
        session = nil
        folderError = nil
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
    }

    private static let bookmarkKey = "lastFolderBookmark"
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
                Text(
                    "This will move all photos into Picked, Rejected, and Undecided folders " +
                        "and close the current session. This cannot be undone from within Keeps."
                )
            }
            .alert("Sorting Complete", isPresented: $showingComplete) {
                Button("OK") { onDismissComplete() }
            } message: {
                Text("Photos have been sorted into folders.")
            }
            .alert("Sorting Failed", isPresented: Binding(
                get: { error != nil },
                set: {
                    if !$0 {
                        error = nil
                    }
                }
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
