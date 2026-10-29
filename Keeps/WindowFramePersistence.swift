import AppKit
import SwiftUI

/// Keeps a folder window's size and position in the folder's keeps.json:
/// restores the saved frame when the window opens, and saves it again
/// whenever the user moves or resizes the window. Draws nothing. Full-screen
/// frames aren't saved, so leaving full screen and quitting reopens the
/// window at its ordinary size.
///
/// The window is already on screen when this view joins it, and SwiftUI
/// resets a size set in that same turn. So the window is made transparent on
/// joining, and the saved frame is applied and the window revealed one turn
/// later: the user never sees it at SwiftUI's default frame. This works from
/// the folder's bookmark rather than an open session so it can join on the
/// window's first render, before the session opens.
struct WindowFramePersistence: NSViewRepresentable {
    let folder: FolderReference
    let onSaveError: @MainActor (Error) -> Void

    func makeNSView(context _: Context) -> TrackingView {
        TrackingView(folder: folder, onSaveError: onSaveError)
    }

    func updateNSView(_: TrackingView, context _: Context) {}

    /// The view that reaches its window once added to one.
    final class TrackingView: NSView {
        private static let frameKey = "windowFrame"

        private let folder: FolderReference
        private let onSaveError: @MainActor (Error) -> Void
        private var observers: [NSObjectProtocol] = []
        private var hasRestored = false

        init(folder: FolderReference, onSaveError: @escaping @MainActor (Error) -> Void) {
            self.folder = folder
            self.onSaveError = onSaveError
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not used")
        }

        isolated deinit {
            stopObserving()
        }

        /// Hides the window until its saved frame is applied, and starts
        /// saving its moves and resizes. A live resize is saved once, when it
        /// ends.
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopObserving()
            guard let window else { return }
            observe(NSWindow.didMoveNotification, on: window) { view in
                view.saveFrame(of: window)
            }
            observe(NSWindow.didResizeNotification, on: window) { view in
                guard !window.inLiveResize else { return }
                view.saveFrame(of: window)
            }
            observe(NSWindow.didEndLiveResizeNotification, on: window) { view in
                view.saveFrame(of: window)
            }
            guard !hasRestored else { return }
            window.alphaValue = 0
            DispatchQueue.main.async { [weak self] in
                self?.restoreFrame(of: window)
            }
        }

        /// Applies the saved frame, if there is one, and reveals the window.
        /// A folder that can't be reached opens at the default frame; the
        /// window reports that failure when it opens the folder's session.
        private func restoreFrame(of window: NSWindow) {
            hasRestored = true
            if let savedFrame = readSavedFrame() {
                window.setFrame(savedFrame, display: false)
            }
            window.alphaValue = 1
        }

        /// The frame saved in keeps.json, or nil when there isn't one or the
        /// folder can't be reached.
        private func readSavedFrame() -> CGRect? {
            guard let folderURL = try? folder.resolve() else { return nil }
            return withFolderFile(at: folderURL) { file in
                file.read(CGRect.self, forKey: Self.frameKey)
            }
        }

        /// Saves the window's frame, once the saved one has been restored and
        /// unless the window is full screen. A folder that can't be reached
        /// is skipped rather than reported: the window already shows that
        /// error, and reporting it here would repeat it on every move.
        private func saveFrame(of window: NSWindow) {
            guard hasRestored, !window.styleMask.contains(.fullScreen),
                  let folderURL = try? folder.resolve()
            else { return }
            do {
                try withFolderFile(at: folderURL) { file in
                    try file.write([Self.frameKey: window.frame])
                }
            } catch {
                onSaveError(error)
            }
        }

        /// Runs `body` with the folder's keeps.json while holding sandbox
        /// access to the folder.
        private func withFolderFile<Result>(
            at folderURL: URL,
            _ body: (KeepsFile) throws -> Result
        ) rethrows -> Result {
            let isAccessing = folderURL.startAccessingSecurityScopedResource()
            defer {
                if isAccessing {
                    folderURL.stopAccessingSecurityScopedResource()
                }
            }
            return try body(KeepsFile(folderURL: folderURL))
        }

        /// Calls `action` with this view whenever the window posts the
        /// notification.
        private func observe(
            _ notificationName: Notification.Name,
            on window: NSWindow,
            action: @escaping @MainActor (TrackingView) -> Void
        ) {
            let observer = NotificationCenter.default.addObserver(
                forName: notificationName,
                object: window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    action(self)
                }
            }
            observers.append(observer)
        }

        /// Stops watching the window.
        private func stopObserving() {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
            observers = []
        }
    }
}
