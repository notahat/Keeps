import Foundation

/// A grid's scroll position in terms that survive relaunching: the item
/// whose row is at the top of the view, and how far into that row the view
/// has scrolled. Unlike a raw offset, it stays meaningful if the items
/// before it change shape or the column count differs.
nonisolated struct GridScrollAnchor: Equatable {
    let itemID: UUID
    let offsetFromRowTop: CGFloat
}
