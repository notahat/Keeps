import SwiftUI

/// The content of one folder window. The folder comes from the window's
/// value. A window with no folder yet (as on first launch) offers to open
/// one and takes on the folder chosen; once a window has a folder it never
/// switches to another. This opens the folder's session and hosts the
/// workflow's root view. Everything shown inside an open folder belongs to
/// the workflow.
struct ContentView: View {
    @Binding var folder: FolderReference?

    @State private var session: FolderSession?
    @State private var folderError: Error?
    @State private var frameSaveError: Error?

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let folderError {
                errorState(folderError)
            } else if let session {
                // The folder as the window's document gives the title bar
                // its folder icon, with the usual drag and Command-click
                // path menu.
                sessionContent(session)
                    .navigationDocument(session.folderURL)
            } else if folder == nil {
                emptyState
            } else {
                // A real (if invisible) view must render while the folder
                // opens: .task never starts for empty content, and the task
                // is what opens the folder.
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(session?.folderURL.lastPathComponent ?? "Keeps")
        .navigationSubtitle(session?.folderURL.path ?? "")
        .frame(minWidth: 500, minHeight: 300)
        .preferredColorScheme(.dark)
        .background {
            if let folder {
                WindowFramePersistence(folder: folder) { frameSaveError = $0 }
            }
        }
        .errorAlert("Couldn't Save Window Position", error: frameSaveError) {
            frameSaveError = nil
        }
        .task(id: folder) {
            openSession()
        }
        .onAppear {
            reopenRememberedFoldersIfLaunching()
        }
        .onDisappear {
            forgetFolderIfUserClosedWindow()
        }
        // Any open window will take a folder handed to the app from
        // outside, such as one dropped on its Dock icon, so SwiftUI only
        // makes a new window for one when none are open.
        .handlesExternalEvents(preferring: [], allowing: ["*"])
        .onOpenURL { url in
            guard let opened = FolderPicker.reference(for: url) else { return }
            // SwiftUI brings this window to the front once the handler
            // returns, so showing the folder waits until after that, or its
            // window would end up behind this one.
            Task {
                show(opened)
            }
        }
    }

    /// Shows a folder the user has picked. If a window already shows it,
    /// that window comes forward, and this one closes if it's empty.
    /// Otherwise an empty window takes the folder on itself, and a window
    /// with a folder opens a new window for it.
    private func show(_ picked: FolderReference) {
        if FolderWindows.bringForward(picked) {
            if folder == nil {
                dismiss()
            }
        } else if folder == nil {
            folder = picked
        } else {
            openWindow(value: picked)
        }
    }

    /// Opens the window's folder, remembers it for the next launch (with a
    /// fresh bookmark if its old one has gone stale) and in Open Recent, or
    /// records the error if it can't be reached or read.
    private func openSession() {
        guard let folder else { return }
        OpenFolderList.shared.add(folder)
        do {
            if let refreshed = try folder.refreshedIfStale() {
                OpenFolderList.shared.replace(folder, with: refreshed)
            }
            let opened = try FolderSession(folderURL: folder.resolve())
            session = opened
            RecentFolders.shared.note(opened.folderURL)
        } catch {
            folderError = error
        }
    }

    /// On the first empty window of a launch, reopens the folders that were
    /// open when the app last quit, each in its own window, and closes this
    /// one. Does nothing if none were open.
    private func reopenRememberedFoldersIfLaunching() {
        guard folder == nil, !AppLifecycle.hasReopenedFolders else { return }
        AppLifecycle.hasReopenedFolders = true
        let remembered = OpenFolderList.shared.folders
        guard !remembered.isEmpty else { return }
        for rememberedFolder in remembered {
            openWindow(value: rememberedFolder)
        }
        dismiss()
    }

    /// Forgets the window's folder when the user closes the window, but not
    /// when the window closes because the app is quitting.
    private func forgetFolderIfUserClosedWindow() {
        guard let folder, !AppLifecycle.isTerminating else { return }
        OpenFolderList.shared.remove(folder)
    }

    /// Asks for a folder and shows it.
    private func chooseFolder() {
        guard let chosen = FolderPicker.chooseFolder() else { return }
        show(chosen)
    }

    /// What an open folder shows: the workflow, or a note that there's
    /// nothing in it to cull.
    @ViewBuilder
    private func sessionContent(_ session: FolderSession) -> some View {
        if session.items.isEmpty {
            noPhotosState
        } else {
            // The one wiring line a workflow experiment replaces.
            GroupCullRootView(session: session)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("Open a folder of photos to get started")
                .foregroundStyle(.secondary)
            Button("Open Folder…", action: chooseFolder)
        }
    }

    private var noPhotosState: some View {
        Text("This folder has no photos")
            .foregroundStyle(.secondary)
    }

    private func errorState(_ error: Error) -> some View {
        VStack(spacing: 8) {
            Text("Couldn't read folder")
                .font(.headline)
            Text(error.localizedDescription)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
