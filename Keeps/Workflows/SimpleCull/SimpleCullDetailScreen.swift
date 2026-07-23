import AppKit
import SwiftUI

/// The single-image screen of the simple culling workflow: a photo detail
/// surface wired to the workflow, with the workflow's chrome — mark badge,
/// position counter, and mark-flash feedback — layered on top. Esc returns
/// to the grid.
struct SimpleCullDetailScreen: View {
    var workflow: SimpleCullWorkflow

    private enum MarkFeedback { case hidden, showing(MarkStore.Mark?) }

    @State private var markFeedback: MarkFeedback = .hidden
    @State private var markFeedbackOpacity: Double = 0

    var body: some View {
        PhotoDetailSurface(
            items: workflow.filteredItems,
            selectedIndex: workflow.selectedIndex,
            onNavigate: { proposal in workflow.selectItem(at: proposal.targetIndex) },
            onKeyDown: { event in handleKeyEvent(event) }
        ) { item in
            chrome(for: item)
        }
        .onChange(of: workflow.lastMarkEvent) { _, event in
            flashMark(event?.mark)
        }
    }

    /// The workflow overlays for the current photo, each anchored to its own
    /// corner of the surface.
    private func chrome(for item: PhotoItem) -> some View {
        ZStack {
            if let mark = workflow.mark(for: item.id) {
                MarkBadge(mark: mark, fontSize: 40)
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            if case let .showing(mark) = markFeedback {
                MarkFeedbackLabel(mark: mark)
                    .opacity(markFeedbackOpacity)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            if let index = workflow.selectedIndex {
                Text("\(index + 1) / \(workflow.filteredItems.count)")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .allowsHitTesting(false)
    }

    /// Handles non-navigation keys: Esc returns to the grid; everything
    /// else goes to the workflow's keymap.
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        if event.keyCode == .escape {
            workflow.viewMode = .grid
            return true
        }
        return workflow.handleKey(event)
    }

    /// Shows the mark feedback label, then fades it out.
    private func flashMark(_ mark: MarkStore.Mark?) {
        markFeedback = .showing(mark)
        markFeedbackOpacity = 1
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 1.5)) {
                markFeedbackOpacity = 0
            }
        }
    }
}

/// The transient label confirming the mark just applied to the previous photo.
private struct MarkFeedbackLabel: View {
    let mark: MarkStore.Mark?

    var body: some View {
        HStack(spacing: 8) {
            markIcon(for: mark)
            Text(message)
                .font(.title3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var message: String {
        switch mark {
        case .pick: "Previous photo picked"
        case .reject: "Previous photo rejected"
        case nil: "Previous photo unmarked"
        }
    }
}
