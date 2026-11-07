import Foundation

/// A grid's scroll position, given by content rather than by a raw offset:
/// the photo shown by the cell whose row is at the top of the view, and how
/// far into that row the view has scrolled. Unlike a raw offset, an anchor
/// stays meaningful if the cells before it change shape or the column count
/// differs. Grouping saves the anchor with the photo's stem in place of its
/// id, which is made afresh at each scan.
nonisolated struct GridScrollAnchor: Equatable {
    /// The id of the photo shown by the cell in the top row.
    let photoID: UUID

    /// How far into that cell's row the view has scrolled, in points.
    let offsetFromRowTop: CGFloat
}
