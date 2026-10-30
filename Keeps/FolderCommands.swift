import SwiftUI

/// Menu commands for the shell: Open Folder…, which takes the place of New
/// Window, since every window shows exactly one folder, and Open Recent.
struct FolderCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open Folder…") {
                if let chosen = FolderPicker.chooseFolder() {
                    show(chosen)
                }
            }
            .keyboardShortcut("o")
            openRecentMenu
        }
    }

    /// The recently opened folders, newest first, with Clear Menu at the
    /// bottom as in other Mac apps.
    private var openRecentMenu: some View {
        Menu("Open Recent") {
            ForEach(RecentFolders.shared.urls, id: \.self) { url in
                Button(url.lastPathComponent) {
                    if let folder = FolderPicker.reference(for: url) {
                        show(folder)
                    }
                }
            }
            Divider()
            Button("Clear Menu") {
                RecentFolders.shared.clear()
            }
            .disabled(RecentFolders.shared.urls.isEmpty)
        }
    }

    /// Brings forward the folder's window, or opens one if it has none.
    private func show(_ folder: FolderReference) {
        if !FolderWindows.bringForward(folder) {
            openWindow(value: folder)
        }
    }
}
