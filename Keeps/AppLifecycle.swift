import AppKit

/// App-wide lifecycle facts the folder windows need: whether the app is
/// quitting (so windows closing then aren't taken as the user closing their
/// folders), and whether this launch has reopened the remembered folders yet.
@MainActor
enum AppLifecycle {
    static var isTerminating = false
    static var hasReopenedFolders = false
}

/// Records when the app starts quitting. AppKit asks this before it closes
/// any windows, so the flag is set in time for their onDisappear.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        AppLifecycle.isTerminating = true
        return .terminateNow
    }
}
