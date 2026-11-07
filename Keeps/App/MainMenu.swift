import AppKit

/// Builds the app's main menu: the app menu, File, and Window, and in debug
/// builds a Debug menu. Each item in the first three sends a standard
/// AppKit action up the responder chain. AppKit adds Open Recent next to
/// Open… and the full-screen items to Window by itself, so they aren't
/// built here.
@MainActor
enum MainMenu {
    /// Makes the whole menu bar.
    static func make() -> NSMenu {
        let menuBar = NSMenu()
        var menus = [appMenu(), fileMenu(), windowMenu()]
        #if DEBUG
            menus.append(debugMenu())
        #endif
        for menu in menus {
            let barItem = NSMenuItem()
            barItem.submenu = menu
            menuBar.addItem(barItem)
        }
        return menuBar
    }

    /// Makes the menu named after the app: About, hiding, and Quit.
    private static func appMenu() -> NSMenu {
        let appName = ProcessInfo.processInfo.processName
        let menu = NSMenu(title: appName)
        menu.addItem(withTitle: "About \(appName)",
                     action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                     keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Hide \(appName)",
                     action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = menu.addItem(withTitle: "Hide Others",
                                      action: #selector(NSApplication.hideOtherApplications(_:)),
                                      keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(withTitle: "Show All",
                     action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit \(appName)",
                     action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    /// Makes the File menu: Open… and Close.
    private static func fileMenu() -> NSMenu {
        let menu = NSMenu(title: "File")
        menu.addItem(withTitle: "Open…",
                     action: #selector(NSDocumentController.openDocument(_:)), keyEquivalent: "o")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Close",
                     action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        return menu
    }

    /// Makes the Window menu and registers it with the app, which lists the
    /// open windows in it.
    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem(withTitle: "Minimize",
                     action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Bring All to Front",
                     action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        NSApplication.shared.windowsMenu = menu
        return menu
    }

    #if DEBUG
        /// Makes the Debug menu, with tools for developing the app.
        private static func debugMenu() -> NSMenu {
            let menu = NSMenu(title: "Debug")
            let showStatistics = menu.addItem(withTitle: "Show Image Statistics",
                                              action: #selector(ImageStatisticsToggle.toggle(_:)), keyEquivalent: "i")
            showStatistics.keyEquivalentModifierMask = [.command, .option]
            showStatistics.target = ImageStatisticsToggle.shared
            return menu
        }
    #endif
}

#if DEBUG
    /// The target of the Debug menu's Show Image Statistics item, which
    /// turns the image statistics overlay on and off, and ticks the item
    /// while it's on. The setting is a user default, so it lasts across
    /// launches, and every window's overlay follows it.
    final class ImageStatisticsToggle: NSObject, NSMenuItemValidation {
        static let shared = ImageStatisticsToggle()

        private var isShown: Bool {
            get { UserDefaults.standard.bool(forKey: ImageStatisticsOverlay.isShownKey) }
            set { UserDefaults.standard.set(newValue, forKey: ImageStatisticsOverlay.isShownKey) }
        }

        /// Turns the overlay on or off.
        @objc func toggle(_: Any?) {
            isShown.toggle()
        }

        /// Ticks the item while the overlay is on.
        func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
            menuItem.state = isShown ? .on : .off
            return true
        }
    }
#endif
