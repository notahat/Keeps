import AppKit
import SwiftUI

/// The root view of the grouping workflow for one folder session. Owns the
/// workflow state and its persistence, hosts the grid screen, and reports
/// save failures with AppKit's standard error alert. The shell hosts this
/// view and knows nothing else about the workflow.
struct GroupCullRootView: View {
    let session: FolderSession

    @State private var workflow: GroupCullWorkflow?
    @State private var persistence: WorkflowPersistence<GroupCullState>?

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
            // At the trailing edge with no glass bubble: background loading
            // is secondary information, not a control.
            ToolbarItem(placement: .primaryAction) {
                LoadProgressView()
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .onAppear {
            start()
        }
        .onDisappear {
            persistence?.stop()
        }
    }

    /// Creates the workflow, restores saved grouping, starts auto-save, and
    /// prefetches thumbnails. Runs once, since a window keeps the same
    /// folder for its whole life.
    private func start() {
        guard workflow == nil else { return }
        let newWorkflow = GroupCullWorkflow(items: session.items)
        let newPersistence = WorkflowPersistence<GroupCullState>(
            folderURL: session.folderURL,
            workflowName: GroupCullState.workflowName
        )
        if let state = newPersistence.restore() {
            newWorkflow.applyRestored(state: state)
        }
        newPersistence.startObserving(
            snapshot: { newWorkflow.snapshotState() },
            onSaveError: { NSApp.presentError($0) }
        )
        workflow = newWorkflow
        persistence = newPersistence
        ImagePipeline.shared.prefetchImages(for: session.items, size: ThumbnailImage.imageSize)
    }
}
