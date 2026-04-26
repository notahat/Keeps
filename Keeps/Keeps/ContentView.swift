import AppKit
import SwiftUI

/// Top-level view. Routes between the grid and single-image views as the library
/// state changes.
struct ContentView: View {
    @State private var library = FolderLibrary()

    /// Tracks the security-scoped URL currently being accessed, so we can stop
    /// access when the user switches to a different folder.
    @State private var securityScopedURL: URL?

    var body: some View {
        Group {
            if library.items.isEmpty {
                emptyState
            } else if library.viewMode == .single {
                SingleImageView(library: library)
            } else {
                GridView(library: library)
            }
        }
        .navigationTitle(library.folderURL?.lastPathComponent ?? "Keeps")
        .navigationSubtitle(library.folderURL?.path ?? "")
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 16) {
                    HStack(spacing: 2) {
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
                    .imageScale(.medium)
                    .font(.body)
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
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: openFolder) {
                    Image(systemName: "folder")
                }
                .help("Open Folder")
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            restoreLastFolder()
        }
    }

    private var emptyState: some View {
        Text("Open a folder to get started")
            .foregroundStyle(.secondary)
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
        guard let index = library.selectedIndex else { return }
        library.setMark(mark, for: library.filteredItems[index])
        let items = library.filteredItems
        library.selectedIndex = items.isEmpty ? nil : min(items.count - 1, index + 1)
    }

    private static let bookmarkKey = "lastFolderBookmark"
}

#Preview {
    ContentView()
}
