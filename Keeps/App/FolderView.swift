import AppKit
import SwiftUI

/// The content of one folder window: the sort screen, the pick screen while
/// a group is open, or a note that the folder has no photos. Owns the folder's grouping and its keeps.json, and
/// reports save failures with AppKit's standard error alert.
struct FolderView: View {
    let session: FolderSession

    @State private var grouping: Grouping?
    @State private var keepsFile: KeepsFile?

    var body: some View {
        Group {
            if session.items.isEmpty {
                Text("This folder has no photos")
                    .foregroundStyle(.secondary)
            } else {
                screen
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .toolbar {
                        // At the trailing edge with no glass bubble:
                        // background loading is secondary information, not a
                        // control.
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
        }
        .frame(minWidth: 500, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
    }

    /// The pick screen while a group is open, otherwise the sort screen,
    /// once start() has made the grouping.
    @ViewBuilder
    private var screen: some View {
        if let grouping, let openGroup = grouping.openGroup {
            // Identified by the group, so moving on to the next group starts
            // the screen afresh.
            PickScreen(grouping: grouping, group: openGroup)
                .id(openGroup)
        } else if let grouping {
            SortScreen(grouping: grouping)
        } else {
            // A real (if invisible) view must render before the grouping
            // exists: onAppear never fires for empty content, and start()
            // — which creates the grouping — hangs off onAppear.
            Color.clear
        }
    }

    /// Creates the grouping, restores it from keeps.json, starts auto-save,
    /// and prefetches thumbnails. Runs once, since a window keeps the same
    /// folder for its whole life.
    private func start() {
        guard grouping == nil else { return }
        let newGrouping = Grouping(items: session.items)
        let newKeepsFile = KeepsFile(folderURL: session.folderURL)
        if let savedGrouping = newKeepsFile.restore() {
            newGrouping.applyRestored(state: savedGrouping)
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
