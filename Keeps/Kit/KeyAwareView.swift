import AppKit
import SwiftUI

/// An invisible NSViewRepresentable that holds first-responder focus and forwards
/// key-down events to a callback. Embed as a .background on a view that needs
/// keyboard input — SwiftUI's ScrollView can't reliably become first responder on
/// macOS, so this AppKit shim handles it instead.
struct KeyAwareView: NSViewRepresentable {
    var onKeyDown: (NSEvent) -> Bool
    /// Called once with the underlying NSView so callers can invoke
    /// window?.makeFirstResponder(_:) to reclaim keyboard focus.
    var onViewReady: ((ResponderView) -> Void)?

    func makeNSView(context _: Context) -> ResponderView {
        let view = ResponderView()
        view.onKeyDown = onKeyDown
        // makeNSView runs during the view update pass, and callers store the
        // view in @State. Defer the callback so that write lands outside the
        // pass; a synchronous call triggers "Modifying state during view
        // update" undefined behaviour.
        let onViewReady = onViewReady
        Task { @MainActor in
            onViewReady?(view)
        }
        return view
    }

    func updateNSView(_ view: ResponderView, context _: Context) {
        view.onKeyDown = onKeyDown
    }

    final class ResponderView: NSView {
        var onKeyDown: ((NSEvent) -> Bool)?
        override var acceptsFirstResponder: Bool {
            true
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
            guard let window else { return }
            if window.isKeyWindow {
                window.makeFirstResponder(self)
            } else {
                // Window may not be key yet at launch — claim focus when it becomes key.
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(windowDidBecomeKey),
                    name: NSWindow.didBecomeKeyNotification,
                    object: window
                )
            }
        }

        @objc private func windowDidBecomeKey() {
            window?.makeFirstResponder(self)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        }

        override func keyDown(with event: NSEvent) {
            if onKeyDown?(event) != true {
                super.keyDown(with: event)
            }
        }
    }
}
