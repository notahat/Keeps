import SwiftUI

/// The root view of the simple culling workflow for one folder session.
/// Owns the workflow state and its persistence, routes between the grid and
/// single-image screens, and provides the toolbar and save-error alert. The
/// shell hosts this view and knows nothing else about the workflow.
struct SimpleCullRootView: View {
    let session: FolderSession

    @State private var workflow: SimpleCullWorkflow?
    @State private var persistence: WorkflowPersistence<SimpleCullState>?

    var body: some View {
        Group {
            if let workflow {
                switch workflow.viewMode {
                case .grid: SimpleCullGridScreen(workflow: workflow)
                case .single: SimpleCullDetailScreen(workflow: workflow)
                }
            } else {
                // A real (if invisible) view must render before the workflow
                // exists: onAppear never fires for empty content, and start()
                // — which creates the workflow — hangs off onAppear.
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar { toolbar }
        .alert("Couldn't Save Changes", isPresented: Binding(
            get: { workflow?.saveError != nil },
            set: {
                if !$0 {
                    workflow?.clearSaveError()
                }
            }
        )) {
            Button("OK") {}
        } message: {
            if let error = workflow?.saveError {
                Text(error.localizedDescription)
            }
        }
        .onAppear {
            start()
        }
        .onDisappear {
            persistence?.stop()
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if let workflow {
            ToolbarItem(placement: .status) {
                HStack(spacing: 8) {
                    LoadProgressView()
                    HStack(spacing: 3) {
                        Text("\(workflow.items.count)")
                            .monospacedDigit()
                            .frame(minWidth: 28, alignment: .trailing)
                        Text("photos")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.leading, 4)
                .padding(.trailing, 12)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                ControlGroup {
                    MarkButton(markAction: .reject, isEnabled: workflow.selectedIndex != nil) {
                        workflow.applyMarkAndAdvance(.reject)
                    }
                    MarkButton(markAction: .unmark, isEnabled: workflow.selectedIndex != nil) {
                        workflow.applyMarkAndAdvance(nil)
                    }
                    MarkButton(markAction: .pick, isEnabled: workflow.selectedIndex != nil) {
                        workflow.applyMarkAndAdvance(.pick)
                    }
                }
            }
        }
    }

    /// Creates the workflow, restores saved marks, starts auto-save, and
    /// prefetches thumbnails. Runs once, since a window keeps the same
    /// folder for its whole life.
    private func start() {
        guard workflow == nil else { return }
        let newWorkflow = SimpleCullWorkflow(items: session.items)
        let newPersistence = WorkflowPersistence<SimpleCullState>(
            folderURL: session.folderURL,
            workflowName: SimpleCullState.workflowName
        )
        if let state = newPersistence.restore() {
            newWorkflow.applyRestored(state: state)
        }
        newPersistence.startObserving(
            read: { _ = newWorkflow.snapshotState() },
            snapshot: { newWorkflow.snapshotState() },
            onSaveError: { newWorkflow.recordSaveError($0) }
        )
        workflow = newWorkflow
        persistence = newPersistence
        ImagePipeline.shared.prefetchImages(for: session.items, size: ThumbnailImage.imageSize)
    }
}
