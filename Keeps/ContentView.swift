import AppKit
import SwiftUI

/// The app shell: opens and restores folders, owns the security bookmarks,
/// and hosts the current workflow's root view. Everything inside the window
/// beyond the open-folder affordances belongs to the workflow.
struct ContentView: View {
    @State private var session: FolderSession?
    @State private var folderError: Error?

    var body: some View {
        Group {
            if let folderError {
                errorState(folderError)
            } else if let session {
                // The one wiring line a workflow experiment replaces.
                SimpleCullRootView(session: session, onSortComplete: closeFolder)
                    .id(session.folderURL)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusedSceneValue(\.openFolderAction) { openFolder() }
        .navigationTitle(session?.folderURL.lastPathComponent ?? "Keeps")
        .navigationSubtitle(session?.folderURL.path ?? "")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: openFolder) {
                    Image(systemName: "folder")
                }
                .help("Open Folder")
            }
        }
        .frame(minWidth: 500, minHeight: 300)
        .preferredColorScheme(.dark)
        .onAppear {
            restoreLastFolder()
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
        folderError = nil
        do {
            session = try FolderSession(folderURL: url)
        } catch {
            session = nil
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

    private func closeFolder() {
        session = nil
        folderError = nil
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
    }

    private static let bookmarkKey = "lastFolderBookmark"
}

#Preview {
    ContentView()
}
