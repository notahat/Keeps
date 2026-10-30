import AppKit

// The app runs on AppKit's document architecture: each open folder is a
// FolderDocument. The document controller is made first so it becomes the
// shared one. Top-level code isn't main-actor isolated, but it runs on the
// main thread, so the setup asserts that.
MainActor.assumeIsolated {
    // Reopen the folders that were open at quit, whatever the system's
    // "Close windows when quitting an application" setting. Registered as a
    // default, so a value set for the app itself still wins.
    UserDefaults.standard.register(defaults: ["NSQuitAlwaysKeepsWindows": true])
    _ = FolderDocumentController()
    let appDelegate = AppDelegate()
    let app = NSApplication.shared
    app.delegate = appDelegate
    app.mainMenu = MainMenu.make()
    // The app holds its delegate weakly, so this keeps it alive while the
    // app runs.
    withExtendedLifetime(appDelegate) {
        app.run()
    }
}
