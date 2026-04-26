import SwiftUI
import AppKit

/// An invisible NSViewRepresentable that holds first-responder focus and forwards
/// key-down events to a callback. Embed as a .background on a view that needs
/// keyboard input — SwiftUI's ScrollView can't reliably become first responder on
/// macOS, so this AppKit shim handles it instead.
struct KeyAwareView: NSViewRepresentable {
    var onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> ResponderView {
        let view = ResponderView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ view: ResponderView, context: Context) {
        view.onKeyDown = onKeyDown
    }

    final class ResponderView: NSView {
        var onKeyDown: ((NSEvent) -> Bool)?
        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window {
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
        }

        @objc private func windowDidBecomeKey() {
            window?.makeFirstResponder(self)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        }

        override func keyDown(with event: NSEvent) {
            if onKeyDown?(event) != true { super.keyDown(with: event) }
        }
    }
}
