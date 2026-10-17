import SwiftUI

extension FocusedValues {
    @Entry var folderOpener: FolderOpener?
}

/// Menu commands for the shell's folder-level actions: opening a folder.
struct FolderCommands: Commands {
    @FocusedValue(\.folderOpener) private var folderOpener

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open Folder...") {
                folderOpener?.openFolder()
            }
            .keyboardShortcut("o")
            .disabled(folderOpener == nil)
        }
    }
}
