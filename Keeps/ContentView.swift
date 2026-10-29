import SwiftUI

/// The app shell: hosts the folder opener's open-folder affordances and the
/// current workflow's root view. Everything inside the window beyond those
/// affordances belongs to the workflow.
struct ContentView: View {
    @State private var folderOpener = FolderOpener()

    var body: some View {
        Group {
            if let folderError = folderOpener.folderError {
                errorState(folderError)
            } else if let session = folderOpener.session, !session.items.isEmpty {
                // The one wiring line a workflow experiment replaces.
                GroupCullRootView(session: session)
                    .id(session.folderURL)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusedSceneValue(\.folderOpener, folderOpener)
        .navigationTitle(folderOpener.session?.folderURL.lastPathComponent ?? "Keeps")
        .navigationSubtitle(folderOpener.session?.folderURL.path ?? "")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: folderOpener.openFolder) {
                    Image(systemName: "folder")
                }
                .help("Open Folder")
            }
        }
        .frame(minWidth: 500, minHeight: 300)
        .preferredColorScheme(.dark)
        .onAppear {
            folderOpener.restoreLastFolder()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("Open a folder of photos to get started")
                .foregroundStyle(.secondary)
            Button("Open Folder...", action: folderOpener.openFolder)
        }
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

#Preview {
    ContentView()
}
