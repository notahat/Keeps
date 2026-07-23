import SwiftUI

extension FocusedValues {
    @Entry var openFolderAction: (() -> Void)?
}

/// Menu commands for the shell's folder-level actions: opening a folder.
struct FolderCommands: Commands {
    @FocusedValue(\.openFolderAction) private var openFolderAction

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open Folder...") {
                openFolderAction?()
            }
            .keyboardShortcut("o")
            .disabled(openFolderAction == nil)
        }
    }
}
