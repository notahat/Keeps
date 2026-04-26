import SwiftUI
import AppKit

/// Top-level view. Routes between the grid and single-image views as the library
/// state changes. For now, shows a plain list while we verify folder scanning.
struct ContentView: View {
    @State private var library = FolderLibrary()

    var body: some View {
        Group {
            if library.items.isEmpty {
                emptyState
            } else {
                itemList
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Open Folder") {
                    openFolder()
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private var emptyState: some View {
        Text("Open a folder to get started")
            .foregroundStyle(.secondary)
    }

    private var itemList: some View {
        GridView(items: library.items)
    }

    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            library.openFolder(url: url)
        }
    }
}

#Preview {
    ContentView()
}
