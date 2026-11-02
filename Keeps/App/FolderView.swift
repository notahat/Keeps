import AppKit
import SwiftUI

/// The content of one folder window: the pick screen while a group is
/// open, otherwise the sidebar of piles beside the section they've chosen,
/// or a note that the folder has no photos. Owns the folder's grouping and
/// its keeps.json, reports save failures with AppKit's standard error
/// alert, and tells the window which section is showing, for its title.
struct FolderView: View {
    let session: FolderSession

    /// Told the section showing, when the view appears and as it changes.
    let onSectionChange: (FolderSection) -> Void

    @State private var grouping: Grouping?
    @State private var keepsFile: KeepsFile?

    /// Which section the piles have chosen. Not saved: a folder always opens
    /// on the photos still to go.
    @State private var section = FolderSection.toGo

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
        .onChange(of: section, initial: true) { _, newSection in
            onSectionChange(newSection)
        }
    }

    /// The folder's screens, once start() has made the grouping.
    @ViewBuilder
    private var screen: some View {
        if let grouping {
            FolderScreens(grouping: grouping, section: $section)
        } else {
            // A real (if invisible) view must render before the grouping
            // exists: onAppear never fires for empty content, and start()
            // — which creates the grouping — hangs off onAppear.
            Color.clear
        }
    }

    /// Creates the grouping, restores it from keeps.json, starts auto-save,
    /// and prefetches thumbnails. Runs once, since a window keeps the same
    /// folder for its whole life. When keeps.json can't be read, says so and
    /// doesn't auto-save, so the work in it isn't written over.
    private func start() {
        guard grouping == nil else { return }
        let newGrouping = Grouping(items: session.items)
        let newKeepsFile = KeepsFile(folderURL: session.folderURL)
        do {
            if let savedGrouping = try newKeepsFile.restore() {
                newGrouping.applyRestored(state: savedGrouping)
            }
            newKeepsFile.startObserving(
                snapshot: { newGrouping.snapshotState() },
                onSaveError: { NSApp.presentError($0) }
            )
        } catch {
            // Shown once the window is up, rather than from inside a view
            // update.
            Task { NSApp.presentError(error) }
        }
        grouping = newGrouping
        keepsFile = newKeepsFile
        ImagePipeline.shared.prefetchImages(for: session.items, size: ThumbnailImage.imageSize)
    }
}

/// The screen for a folder's grouping: the pick screen while a group is
/// open, otherwise the section the piles have chosen, with the piles beside
/// it once there are done groups to navigate to. FolderView owns the
/// grouping and the section; this only shows them.
private struct FolderScreens: View {
    let grouping: Grouping
    @Binding var section: FolderSection

    var body: some View {
        if let openGroup = grouping.openGroup {
            // Identified by the group, so opening a different group starts
            // the screen afresh.
            PickScreen(grouping: grouping, group: openGroup)
                .id(openGroup)
        } else {
            sectionWithPiles
        }
    }

    /// The section's screen with the piles beside it.
    private var sectionWithPiles: some View {
        // The piles are a sidebar on the left, from the top, where Mac apps
        // keep their navigation. They take only their own size, so the
        // screen gets all the rest of the width.
        HStack(alignment: .top, spacing: 0) {
            // Only once a group is done: until then, every photo is to go
            // and there's nowhere else to navigate to.
            if grouping.doneGroupCount > 0 {
                FolderPiles(grouping: grouping, section: $section)
                    .fixedSize()
                    .padding(16)
            }
            sectionScreen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // With no done groups, the set-aside pile that leads to them is
        // gone, so their section can't stay showing. Checked on appear too,
        // for coming back from un-marking the last one.
        .onChange(of: grouping.doneGroupCount, initial: true) { _, count in
            if count == 0, section == .done {
                section = .toGo
            }
        }
    }

    /// The screen for the section the piles have chosen.
    @ViewBuilder
    private var sectionScreen: some View {
        switch section {
        case .toGo:
            SortScreen(grouping: grouping)
        case .done:
            DoneScreen(grouping: grouping)
        }
    }
}
