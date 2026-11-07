import Foundation

/// A grid's scroll position, given by content rather than by pixels: the
/// photo shown by the cell whose row is at the top of the view, and how far
/// into that row the view has scrolled. Unlike a raw offset, it stays
/// meaningful if the cells before it change shape or the column count
/// differs. Grouping saves it with the photo's stem in place of its id,
/// which is made afresh at each scan.
nonisolated struct GridScrollAnchor: Equatable {
    let photoID: UUID
    let offsetFromRowTop: CGFloat
}
