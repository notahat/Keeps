import AppKit
import SwiftUI

/// Top-level view. Routes between the grid and single-image views as the library
/// state changes.
struct ContentView: View {
    @State private var library = FolderLibrary()

    /// Tracks the security-scoped URL currently being accessed, so we can stop
    /// access when the user switches to a different folder.
    @State private var securityScopedURL: URL?

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
            .navigationTitle(library.folderURL?.lastPathComponent ?? "Keeps")
            .navigationSubtitle(library.folderURL?.path ?? "")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: openFolder) {
                        Image(systemName: "folder")
                    }
                    .help("Open Folder")
                }

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
                        Text("\(library.filteredItems.count) photos")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        LoadGraphView()
                    }
                    .padding(.leading, 8)
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
        }
        .frame(minWidth: 500, minHeight: 300)
        .preferredColorScheme(.dark)
        .onAppear {
            restoreLastFolder()
        }
    }

    private var emptyState: some View {
        Text("Open a folder to get started")
            .foregroundStyle(.secondary)
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

        stopCurrentAccess()
        saveBookmark(for: url)
        library.openFolder(url: url)
        ImagePipeline.shared.prefetchImages(for: library.items, size: ThumbnailView.imageSize)
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

        guard url.startAccessingSecurityScopedResource() else { return }
        securityScopedURL = url

        if isStale { saveBookmark(for: url) }
        library.openFolder(url: url)
        ImagePipeline.shared.prefetchImages(for: library.items, size: ThumbnailView.imageSize)
    }

    private func stopCurrentAccess() {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
    }

    private func saveBookmark(for url: URL) {
        let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: Self.bookmarkKey)
    }

    private func applyMark(_ mark: FolderLibrary.Mark?) {
        library.applyMarkAndAdvance(mark)
    }

    private static let bookmarkKey = "lastFolderBookmark"
}

#Preview {
    ContentView()
}
