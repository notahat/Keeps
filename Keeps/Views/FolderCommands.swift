import SwiftUI

extension FocusedValues {
    @Entry var sortPhotosAction: (() -> Void)?
}

/// Menu command for the folder-level "Sort Photos into Folders" action,
/// placed in the File menu.
struct FolderCommands: Commands {
    @FocusedValue(\.sortPhotosAction) private var sortPhotosAction

    var body: some Commands {
        CommandGroup(after: .importExport) {
            Button("Sort Photos into Folders...") {
                sortPhotosAction?()
            }
            .disabled(sortPhotosAction == nil)
        }
    }
}
