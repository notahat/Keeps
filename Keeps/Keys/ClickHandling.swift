import SwiftUI

/// Click handling the screens share, so a click and a double click on a
/// cell, tile, or pile behave the same way on every screen.
extension View {
    /// Call `handleClick` on every click, and `handleDoubleClick` on a
    /// double click, each with where the click landed in this view's own
    /// coordinates. A double click calls `handleClick` for its first click
    /// too, so a double click selects before it acts.
    ///
    /// The single click is a simultaneous gesture rather than a second tap
    /// gesture. SwiftUI would hold back a plain single tap until the
    /// double-click time had passed, to rule out a double click, so the
    /// selection would lag behind the click.
    func onClick(
        perform handleClick: @escaping (CGPoint) -> Void,
        onDoubleClick handleDoubleClick: @escaping (CGPoint) -> Void
    ) -> some View {
        onTapGesture(count: 2, coordinateSpace: .local, perform: handleDoubleClick)
            .simultaneousGesture(SpatialTapGesture(coordinateSpace: .local).onEnded { tap in
                handleClick(tap.location)
            })
    }
}
