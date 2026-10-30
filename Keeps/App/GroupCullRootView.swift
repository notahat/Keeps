import AppKit
import SwiftUI

/// The view of a folder with photos. Owns the grouping and its keeps.json,
/// hosts the sort screen, and reports save failures with AppKit's standard
/// error alert.
struct GroupCullRootView: View {
    let session: FolderSession

    @State private var grouping: Grouping?
    @State private var keepsFile: KeepsFile?

    var body: some View {
        Group {
            if let grouping {
                SortScreen(grouping: grouping)
            } else {
                // A real (if invisible) view must render before the grouping
                // exists: onAppear never fires for empty content, and start()
                // — which creates the grouping — hangs off onAppear.
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
            keepsFile?.stop()
        }
    }

    /// Creates the grouping, restores saved grouping, starts auto-save, and
    /// prefetches thumbnails. Runs once, since a window keeps the same
    /// folder for its whole life.
    private func start() {
        guard grouping == nil else { return }
        let newGrouping = Grouping(items: session.items)
        let newKeepsFile = KeepsFile(folderURL: session.folderURL)
        if let state = newKeepsFile.restore() {
            newGrouping.applyRestored(state: state)
        }
        newKeepsFile.startObserving(
            snapshot: { newGrouping.snapshotState() },
            onSaveError: { NSApp.presentError($0) }
        )
        grouping = newGrouping
        keepsFile = newKeepsFile
        ImagePipeline.shared.prefetchImages(for: session.items, size: ThumbnailImage.imageSize)
    }
}
