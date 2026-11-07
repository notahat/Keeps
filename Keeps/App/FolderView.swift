import AppKit
import SwiftUI

/// The content of one folder window.
///
/// The app has four main screens: sort, pick, done, and keepers. The pick
/// screen takes over the whole window whenever a group is open. Otherwise
/// the window shows one of the other three, and which one it shows is the
/// section (FolderSection). The user selects the
/// section by clicking a pile in the sidebar (FolderSidebar).
///
/// FolderView owns the folder's grouping, its keeps.json, and the section,
/// and sets up the grouping and keeps.json when the window opens. It shows
/// the current screen (see CurrentScreen), or a note when the folder has no
/// photos. It reports keeps.json errors with AppKit's standard error alert,
/// and tells the window which section is showing, for its title.
struct FolderView: View {
    let session: FolderSession

    /// Called with the section that's showing when the view appears, and
    /// again whenever the user selects a different one, so the window can
    /// show the section's name in its title.
    let onSectionChange: (FolderSection) -> Void

    @State private var grouping: Grouping?
    @State private var keepsFile: KeepsFile?

    /// The section the user has selected by clicking a pile in the sidebar.
    /// Not saved: a folder always opens on the photos still to go.
    @State private var section = FolderSection.toGo

    var body: some View {
        Group {
            if session.items.isEmpty {
                Text("This folder has no photos")
                    .foregroundStyle(.secondary)
            } else {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .bottomLeading) {
                        ImageStatsOverlay()
                            .padding(12)
                    }
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
                        keepsFile?.stopAutoSaving()
                    }
            }
        }
        .frame(minWidth: 500, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
        .onChange(of: section, initial: true) { _, newSection in
            onSectionChange(newSection)
        }
    }

    /// What the window shows: the current screen once start() has made the
    /// grouping, and an invisible placeholder until then.
    @ViewBuilder
    private var content: some View {
        if let grouping {
            CurrentScreen(grouping: grouping, section: $section)
        } else {
            // start() creates the grouping, and runs from onAppear. SwiftUI
            // never calls onAppear on empty content, so without a view here
            // start() would never run. Color.clear is a view that shows
            // nothing.
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
            newKeepsFile.startAutoSaving(
                snapshot: { newGrouping.snapshotState() },
                onSaveError: { NSApp.presentError($0) }
            )
        } catch {
            // presentError runs a modal alert, which waits for the user.
            // Called directly, it would block SwiftUI partway through
            // showing the window. The Task presents it once that's done.
            Task { NSApp.presentError(error) }
        }
        grouping = newGrouping
        keepsFile = newKeepsFile
        ImagePipeline.shared.prefetchImages(for: session.items, size: .thumbnail)
    }
}

/// The one screen the window is on: the pick screen while a group is open,
/// otherwise the screen for the section the user has selected, with the
/// sidebar beside it once there are done groups to go to. FolderView owns
/// the grouping and the section; this only shows them.
private struct CurrentScreen: View {
    let grouping: Grouping
    @Binding var section: FolderSection

    var body: some View {
        if let openGroup = grouping.openGroup {
            // The id tells SwiftUI to build a new pick screen whenever a
            // different group opens. Without it, SwiftUI would reuse the
            // old one, and its state, such as which tile has focus, would
            // carry over to the new group.
            PickScreen(grouping: grouping, group: openGroup)
                .id(openGroup)
        } else {
            sectionWithSidebar
        }
    }

    /// The section's screen with the sidebar beside it.
    private var sectionWithSidebar: some View {
        // The sidebar is on the left, from the top, where Mac apps keep
        // their navigation. It takes only its own size, so the screen gets
        // all the rest of the width.
        HStack(alignment: .top, spacing: 0) {
            // Only once a group is done: until then, every photo is to go
            // and there's nowhere else to navigate to.
            if grouping.doneGroupCount > 0 {
                FolderSidebar(grouping: grouping, section: $section)
                    .fixedSize()
                    .padding(16)
            }
            sectionScreen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Switches back to the sort screen when the section showing has
        // nothing left in it, since its pile is gone from the sidebar. This
        // happens when the user opens a done group, un-marks it or its
        // keepers, and closes it, so it runs when this view appears.
        .onChange(of: availableSection, initial: true) { _, available in
            section = available
        }
    }

    /// The section to show: the one the user selected, unless it has
    /// nothing left in it.
    private var availableSection: FolderSection {
        section.availableSection(
            hasDoneGroups: grouping.doneGroupCount > 0,
            hasKeepers: !grouping.keepersOfDoneGroups.isEmpty
        )
    }

    /// The screen for the section the user has selected.
    @ViewBuilder
    private var sectionScreen: some View {
        switch section {
        case .toGo:
            SortScreen(grouping: grouping)
        case .done:
            DoneScreen(grouping: grouping)
        case .keepers:
            KeepersScreen(grouping: grouping)
        }
    }
}
