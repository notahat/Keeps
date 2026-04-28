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
            Button("Pull to Current Pass") { pullToCurrentPass() }
                .keyboardShortcut("u", modifiers: .command)
                .disabled(!canPullToCurrentPass)
        }
    }

    private var canPullToCurrentPass: Bool {
        guard let library else { return false }
        return library.selectedIndex != nil
            && library.currentPassIndex < library.passes.count - 1
    }

    private func pullToCurrentPass() {
        guard let library,
              let index = library.selectedIndex
        else { return }
        library.pullToCurrentPass(item: library.filteredItems[index])
    }
}
