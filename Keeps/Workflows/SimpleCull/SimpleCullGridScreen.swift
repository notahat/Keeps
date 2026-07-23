import AppKit
import SwiftUI

/// The grid screen of the simple culling workflow: a photo grid surface
/// wired to the library's selection, marks, and navigation policy.
struct SimpleCullGridScreen: View {
    var library: FolderLibrary

    var body: some View {
        PhotoGridSurface(
            items: library.filteredItems,
            selectedIndex: library.selectedIndex,
            onNavigate: { proposal in
                if proposal.extendsRange {
                    library.extendSelection(to: proposal.targetIndex)
                } else {
                    library.selectItem(at: proposal.targetIndex)
                }
            },
            onKeyDown: { event in handleKeyEvent(event) },
            onTap: { index, extendsRange in
                if extendsRange {
                    library.extendSelection(to: index)
                } else {
                    library.selectItem(at: index)
                }
            },
            onDoubleTap: { index in
                library.selectItem(at: index)
                library.viewMode = .single
            }
        ) { item, index in
            SimpleCullCell(
                item: item,
                isSelected: item.id == library.selectedItemID,
                isInSelectionRange: library.selectionRange?.contains(index) ?? false,
                mark: library.mark(for: item.id)
            )
        }
    }

    /// Handles non-navigation keys: Return enters the single-image view.
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        if event.keyCode == .returnKey, library.selectedIndex != nil {
            library.viewMode = .single
            return true
        }
        return false
    }
}
