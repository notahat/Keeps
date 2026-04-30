import SwiftUI

@main
struct KeepsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            PhotoCommands()
            FolderCommands()
        }
    }
}
