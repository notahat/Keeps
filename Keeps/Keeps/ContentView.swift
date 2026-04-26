import SwiftUI
import AppKit

/// Top-level view. Routes between the grid and single-image views as the library
/// state changes.
struct ContentView: View {
    @State private var library = FolderLibrary()

    // Tracks the security-scoped URL currently being accessed, so we can stop
    // access when the user switches to a different folder.
    @State private var securityScopedURL: URL?

    var body: some View {
        Group {
            if library.items.isEmpty {
                emptyState
            } else {
                GridView(library: library)
            }
        }
        .navigationTitle(library.folderURL?.lastPathComponent ?? "Keeps")
        .navigationSubtitle(library.folderURL.map { abbreviatedPath($0) } ?? "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Open Folder") {
                    openFolder()
                }
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

    private func abbreviatedPath(_ url: URL) -> String {
        let path = url.path
        guard let pw = getpwuid(getuid()), let home = String(validatingCString: pw.pointee.pw_dir) else {
            return path
        }
        guard path.hasPrefix(home) else { return path }
        return "~" + String(path.dropFirst(home.count))
    }

    private static let bookmarkKey = "lastFolderBookmark"
}

#Preview {
    ContentView()
}
