import SwiftUI

extension FocusedValues {
    @Entry var library: FolderLibrary?
}

/// Menu commands for the Photo menu, providing pick/reject/unmark actions
/// with keyboard shortcuts.
struct PhotoCommands: Commands {
    @FocusedValue(\.library) private var library

    var body: some Commands {
        CommandMenu("Photo") {
            Button("Pick") { library?.applyMarkAndAdvance(.pick) }
                .keyboardShortcut("f", modifiers: [])
                .disabled(library?.selectedIndex == nil)
            Button("Reject") { library?.applyMarkAndAdvance(.reject) }
                .keyboardShortcut("s", modifiers: [])
                .disabled(library?.selectedIndex == nil)
            Button("Unmark") { library?.applyMarkAndAdvance(nil) }
                .keyboardShortcut("d", modifiers: [])
                .disabled(library?.selectedIndex == nil)
            Divider()
            Button("Group Selection") { library?.createGroupFromSelection() }
                .keyboardShortcut("g", modifiers: [])
                .disabled((library?.selectedRangeItems.count ?? 0) < 2)
            Button("Ungroup") { library?.ungroupSelectedItem() }
                .disabled(library?.selectedItemIsGrouped != true)
            Button("Reject Rest of Group") { library?.rejectRestOfGroup() }
                .disabled(library?.selectedItemIsGrouped != true)
        }
    }
}
