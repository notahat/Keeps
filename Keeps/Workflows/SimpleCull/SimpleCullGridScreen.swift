import AppKit
import SwiftUI

/// The grid screen of the simple culling workflow: a photo grid surface
/// wired to the workflow's selection, marks, and navigation policy.
struct SimpleCullGridScreen: View {
    var workflow: SimpleCullWorkflow

    var body: some View {
        PhotoGridSurface(
            items: workflow.filteredItems,
            selectedIndex: workflow.selectedIndex,
            onNavigate: { proposal in
                if proposal.extendsRange {
                    workflow.extendSelection(to: proposal.targetIndex)
                } else {
                    workflow.selectItem(at: proposal.targetIndex)
                }
            },
            onKeyDown: { event in handleKeyEvent(event) },
            onTap: { index, extendsRange in
                if extendsRange {
                    workflow.extendSelection(to: index)
                } else {
                    workflow.selectItem(at: index)
                }
            },
            onDoubleTap: { index in
                workflow.selectItem(at: index)
                workflow.viewMode = .single
            }
        ) { item, index in
            SimpleCullCell(
                item: item,
                isSelected: item.id == workflow.selectedItemID,
                isInSelectionRange: workflow.selectionRange?.contains(index) ?? false,
                mark: workflow.mark(for: item.id)
            )
        }
    }

    /// Handles non-navigation keys: Return enters the single-image view;
    /// everything else goes to the workflow's keymap.
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        if event.keyCode == .returnKey, workflow.selectedIndex != nil {
            workflow.viewMode = .single
            return true
        }
        return workflow.handleKey(event)
    }
}
