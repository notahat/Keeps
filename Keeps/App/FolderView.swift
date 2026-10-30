import SwiftUI

/// The content of one folder window: the sort screen, or a note that the
/// folder has no photos.
struct FolderView: View {
    let session: FolderSession

    var body: some View {
        Group {
            if session.items.isEmpty {
                Text("This folder has no photos")
                    .foregroundStyle(.secondary)
            } else {
                GroupCullRootView(session: session)
            }
        }
        .frame(minWidth: 500, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
    }
}
