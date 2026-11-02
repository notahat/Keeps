import SwiftUI

/// The accent-coloured outline round a selected photo or pile, the same on
/// every screen. It shows only while the window is key, as selections do in
/// Finder. Draws only; which item is selected is the screen's business.
struct SelectionHighlight: ViewModifier {
    /// The outline's line width. It's centred on the item's edge, leaving a
    /// little space between it and the photo, so half of it falls outside
    /// the item.
    static let lineWidth: CGFloat = 3

    let isSelected: Bool

    @Environment(\.controlActiveState) private var controlActiveState

    /// The content with the outline over it while selected in a key window.
    func body(content: Content) -> some View {
        content.overlay {
            if isSelected, controlActiveState == .key {
                Rectangle().stroke(Color.accentColor, lineWidth: Self.lineWidth)
            }
        }
    }
}

extension View {
    /// Outlines this view while it's selected (see SelectionHighlight).
    func selectionHighlight(isSelected: Bool) -> some View {
        modifier(SelectionHighlight(isSelected: isSelected))
    }
}
