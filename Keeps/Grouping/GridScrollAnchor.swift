import Foundation

/// A grid's scroll position, given by content rather than by pixels: the
/// item whose row is at the top of the view, and how far into that row the
/// view has scrolled. Unlike a raw offset, it stays meaningful if the items
/// before it change shape or the column count differs. Grouping saves it
/// with the item's stem in place of its id, which is made afresh at each
/// scan.
nonisolated struct GridScrollAnchor: Equatable {
    let itemID: UUID
    let offsetFromRowTop: CGFloat
}
