import SwiftUI

/// The root view of the simple culling workflow for one folder session.
/// Owns the workflow state and its persistence, routes between the grid and
/// single-image screens, and provides the toolbar, sort flow, and
/// save-error alert. The shell hosts this view and knows nothing else about
/// the workflow.
struct SimpleCullRootView: View {
    let session: FolderSession

    /// Called after a destructive sort completes so the shell can close the
    /// folder.
    var onSortComplete: () -> Void

    @State private var workflow: SimpleCullWorkflow?
    @State private var persistence: WorkflowPersistence<SimpleCullState>?

    @State private var showingSortConfirmation = false
    @State private var showingSortComplete = false
    @State private var sortError: String?

    var body: some View {
        Group {
            if let workflow {
                switch workflow.viewMode {
                case .grid: SimpleCullGridScreen(workflow: workflow)
                case .single: SimpleCullDetailScreen(workflow: workflow)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar { toolbar }
        .modifier(SortDialogs(
            showingConfirmation: $showingSortConfirmation,
            showingComplete: $showingSortComplete,
            error: Binding(
                get: { sortError },
                set: { sortError = $0 }
            ),
            onSort: performSort,
            onDismissComplete: onSortComplete
        ))
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
            ToolbarItem(placement: .principal) {
                Picker("Filter", selection: Binding(
                    get: { workflow.filterMode },
                    set: { workflow.applyFilter($0) }
                )) {
                    Text("All").tag(SimpleCullWorkflow.FilterMode.all)
                    Text("Picked").tag(SimpleCullWorkflow.FilterMode.picked)
                    Text("Rejected").tag(SimpleCullWorkflow.FilterMode.rejected)
                    Text("Unmarked").tag(SimpleCullWorkflow.FilterMode.unmarked)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            ToolbarItem(placement: .status) {
                HStack(spacing: 8) {
                    LoadGraphView()
                    HStack(spacing: 3) {
                        Text("\(workflow.filteredItems.count)")
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

                Button {
                    showingSortConfirmation = true
                } label: {
                    Image(systemName: "square.grid.3x1.folder.badge.plus")
                }
                .help("Sort Photos into Folders")
            }
        }
    }

    /// Creates the workflow, restores saved marks, starts auto-save, and
    /// prefetches thumbnails. Runs once per session; the shell re-creates
    /// this view (via .id) when the folder changes.
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

    /// Moves the photos into Picked/Rejected/Undecided folders and deletes
    /// keeps.json. Destructive and final: on success the completion alert
    /// hands control back to the shell to close the folder.
    private func performSort() {
        guard let workflow, let persistence else { return }
        let folderURL = session.folderURL
        let moves = PhotoSorter.plannedMoves(folderURL: folderURL, sortPlan: workflow.sortPlan())
        do {
            try PhotoSorter.execute(folderURL: folderURL, moves: moves)
            persistence.stop()
            try PhotoSorter.deleteKeepsJSON(in: folderURL)
            showingSortComplete = true
        } catch {
            sortError = error.localizedDescription
        }
    }
}

/// Bundles the confirmation dialog, success alert, and error alert for the
/// sort-photos-into-folders action.
private struct SortDialogs: ViewModifier {
    @Binding var showingConfirmation: Bool
    @Binding var showingComplete: Bool
    @Binding var error: String?
    var onSort: () -> Void
    var onDismissComplete: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Sort Photos into Folders?",
                isPresented: $showingConfirmation
            ) {
                Button("Sort", role: .destructive) { onSort() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "This will move all photos into Picked, Rejected, and Undecided folders " +
                        "and close the current session. This cannot be undone from within Keeps."
                )
            }
            .alert("Sorting Complete", isPresented: $showingComplete) {
                Button("OK") { onDismissComplete() }
            } message: {
                Text("Photos have been sorted into folders.")
            }
            .alert("Sorting Failed", isPresented: Binding(
                get: { error != nil },
                set: {
                    if !$0 {
                        error = nil
                    }
                }
            )) {
                Button("OK") {}
            } message: {
                if let error {
                    Text(error)
                }
            }
    }
}
