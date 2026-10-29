import SwiftUI

/// The app: one window per open photo folder. The app reopens the folders
/// that were open when it last quit (see OpenFolderList) rather than relying
/// on system window restoration, which macOS turns off by default.
@main
struct KeepsApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup(for: FolderReference.self) { $folder in
            ContentView(folder: $folder)
        }
        .restorationBehavior(.disabled)
        .commands {
            FolderCommands()
        }
    }
}
