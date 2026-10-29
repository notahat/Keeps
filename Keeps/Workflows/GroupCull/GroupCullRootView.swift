import SwiftUI

/// The root view of the grouping workflow for one folder session. Owns the
/// workflow state and hosts the grid screen. The shell hosts this view and
/// knows nothing else about the workflow.
struct GroupCullRootView: View {
    let session: FolderSession

    @State private var workflow: GroupCullWorkflow?

    var body: some View {
        Group {
            if let workflow {
                GroupCullGridScreen(workflow: workflow)
            } else {
                // A real (if invisible) view must render before the workflow
                // exists: onAppear never fires for empty content, and start()
                // — which creates the workflow — hangs off onAppear.
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .status) {
                LoadGraphView().padding(.horizontal, 12)
            }
        }
        .onAppear {
            start()
        }
    }

    /// Creates the workflow and prefetches thumbnails. Runs once per
    /// session; the shell re-creates this view (via .id) when the folder
    /// changes.
    private func start() {
        guard workflow == nil else { return }
        workflow = GroupCullWorkflow(items: session.items)
        ImagePipeline.shared.prefetchImages(for: session.items, size: ThumbnailImage.imageSize)
    }
}
