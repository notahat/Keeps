import SwiftUI

/// The accent-coloured outline round a selected photo or pile, the same on
/// every screen. It shows only while the window is key, as selections do in
/// Finder. It only draws the outline; each screen tracks which item is
/// selected.
struct SelectionHighlight: ViewModifier {
    /// The outline's line width. The line is centred on the item's edge, so
    /// half of it falls outside the item, and the inner half sits in the
    /// space ThumbnailImage leaves round the photo (its imageInset).
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
