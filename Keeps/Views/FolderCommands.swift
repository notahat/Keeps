import SwiftUI

extension FocusedValues {
    @Entry var openFolderAction: (() -> Void)?
    @Entry var sortPhotosAction: (() -> Void)?
}

/// Menu commands for folder-level actions: opening a folder and sorting
/// photos into subdirectories.
struct FolderCommands: Commands {
    @FocusedValue(\.openFolderAction) private var openFolderAction
    @FocusedValue(\.sortPhotosAction) private var sortPhotosAction

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open Folder...") {
                openFolderAction?()
            }
            .keyboardShortcut("o")
            .disabled(openFolderAction == nil)
        }

        CommandGroup(after: .importExport) {
            Button("Sort Photos into Folders...") {
                sortPhotosAction?()
            }
            .disabled(sortPhotosAction == nil)
        }
    }
}
