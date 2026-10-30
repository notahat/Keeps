import SwiftUI

/// The content of one folder window: the workflow, or a note that the folder
/// has nothing in it to cull. Everything shown inside a folder with photos
/// belongs to the workflow.
struct FolderView: View {
    let session: FolderSession

    var body: some View {
        Group {
            if session.items.isEmpty {
                Text("This folder has no photos")
                    .foregroundStyle(.secondary)
            } else {
                // The one wiring line a workflow experiment replaces.
                GroupCullRootView(session: session)
            }
        }
        .frame(minWidth: 500, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
    }
}
