import SwiftUI

/// The content of one folder window. Each window shows a single folder for
/// its whole life — the folder comes from the window's value and is never
/// switched — so this opens that folder's session and hosts the workflow's
/// root view. A window with no folder yet (as on first launch) offers to open
/// one. Everything shown inside an open folder belongs to the workflow.
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
                if session.items.isEmpty {
                    noPhotosState
                } else {
                    // The one wiring line a workflow experiment replaces.
                    GroupCullRootView(session: session)
                }
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
        .alert("Couldn't Save Window Position", isPresented: Binding(
            get: { frameSaveError != nil },
            set: { isPresented in
                if !isPresented {
                    frameSaveError = nil
                }
            }
        )) {
            Button("OK") {}
        } message: {
            if let frameSaveError {
                Text(frameSaveError.localizedDescription)
            }
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
    }

    /// Opens the window's folder and remembers it for the next launch, or
    /// records the error if it can't be reached or read.
    private func openSession() {
        session = nil
        folderError = nil
        guard let folder else { return }
        OpenFolderList.shared.add(folder)
        do {
            session = try FolderSession(folderURL: folder.resolve())
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

    /// Asks for a folder and opens it in its own window, replacing this empty
    /// one. Going through openWindow means a folder that's already open
    /// brings its existing window forward.
    private func chooseFolder() {
        guard let chosen = FolderPicker.chooseFolder() else { return }
        openWindow(value: chosen)
        dismiss()
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
