import Foundation

/// Where a pointer event inside a grid cell landed: on the item itself, or on
/// the gap between two items. The outer edges of each cell stand in for the
/// gap, because the real gap is too thin to hit quickly. Gaps are numbered by
/// the index of the item that follows them, so the right edge of one cell and
/// the left edge of the next — even across a row wrap — resolve to the same
/// gap. The gap after the last item is a valid target; there is none before
/// the first. What a gap is used for, such as placing a boundary, is up to
/// the caller.
nonisolated enum GridHitTarget: Equatable {
    case item(Int)
    case gap(beforeIndex: Int)

    /// The gap this targets, or nil when it targets an item.
    var gapIndex: Int? {
        if case let .gap(beforeIndex) = self {
            beforeIndex
        } else {
            nil
        }
    }

    /// The fraction of the cell's width, on each side, that targets a gap.
    static let edgeFraction: CGFloat = 0.2

    /// Resolves a horizontal offset from the left of the cell at `index` to
    /// a target. Pure.
    static func resolve(offset: CGFloat, cellWidth: CGFloat, index: Int) -> GridHitTarget {
        let edgeWidth = cellWidth * edgeFraction
        if offset < edgeWidth, index > 0 {
            return .gap(beforeIndex: index)
        }
        if offset > cellWidth - edgeWidth {
            return .gap(beforeIndex: index + 1)
        }
        return .item(index)
    }
}
