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
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ view: ResponderView, context: Context) {
        view.onKeyDown = onKeyDown
        DispatchQueue.main.async {
            guard view.window?.isKeyWindow == true, view.window?.firstResponder !== view else { return }
            view.window?.makeFirstResponder(view)
        }
    }

    final class ResponderView: NSView {
        var onKeyDown: ((NSEvent) -> Bool)?
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            if onKeyDown?(event) != true { super.keyDown(with: event) }
        }
    }
}
