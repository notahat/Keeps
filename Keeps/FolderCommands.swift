import SwiftUI

/// Menu commands for the shell: Open Folder…, which takes the place of New
/// Window, since every window shows exactly one folder.
struct FolderCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open Folder…") {
                if let chosen = FolderPicker.chooseFolder() {
                    openWindow(value: chosen)
                }
            }
            .keyboardShortcut("o")
        }
    }
}
