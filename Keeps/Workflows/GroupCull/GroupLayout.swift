import Foundation

/// Works out, from a folder's group boundaries, which groups exist, which are
/// collapsed, and which cells the grid should show. Pure: it holds no state
/// beyond its inputs and does no drawing.
///
/// A boundary is the index of the first photo after it, so a boundary equal
/// to the photo count closes the final group. The folder always starts a
/// group at photo 0. Photos after the last boundary are not in any group yet.
nonisolated struct GroupLayout {
    /// One cell in the grid: a single photo, or a collapsed group shown as
    /// one cell.
    enum Cell: Equatable {
        case photo(Int)
        case collapsedGroup(Range<Int>)

        /// The photos this cell stands for.
        var photoRange: Range<Int> {
            switch self {
            case let .photo(index): index ..< index + 1
            case let .collapsedGroup(range): range
            }
        }
    }

    /// How many of the most recently closed groups stay open, so the latest
    /// boundaries can still be adjusted in context.
    static let openGroupCount = 2

    let photoCount: Int
    let groups: [Range<Int>]
    let cells: [Cell]

    init(photoCount: Int, boundaries: Set<Int>, expandedRange: Range<Int>? = nil) {
        self.photoCount = photoCount
        groups = Self.groups(photoCount: photoCount, boundaries: boundaries)
        cells = Self.cells(photoCount: photoCount, groups: groups, expandedRange: expandedRange)
    }

    /// The photo index that a gap between cells corresponds to: the first
    /// photo of the cell after the gap, or the photo count for the gap after
    /// the last cell.
    func photoIndex(forGap gapIndex: Int) -> Int {
        cells.indices.contains(gapIndex) ? cells[gapIndex].photoRange.lowerBound : photoCount
    }

    /// The index of the cell that shows the given photo.
    func cellIndex(containing photoIndex: Int) -> Int? {
        cells.firstIndex { $0.photoRange.contains(photoIndex) }
    }

    /// The closed groups, in order. Boundaries outside the folder, or at its
    /// very start, are ignored.
    private static func groups(photoCount: Int, boundaries: Set<Int>) -> [Range<Int>] {
        let ends = boundaries.filter { $0 >= 1 && $0 <= photoCount }.sorted()
        let starts = [0] + ends.dropLast()
        return zip(starts, ends).map { start, end in start ..< end }
    }

    /// The grid cells: older groups collapsed unless they overlap the
    /// expanded range, everything else as individual photos.
    private static func cells(photoCount: Int, groups: [Range<Int>], expandedRange: Range<Int>?) -> [Cell] {
        let collapsibleCount = max(0, groups.count - openGroupCount)
        var cells: [Cell] = []
        for (groupIndex, group) in groups.enumerated() {
            let isExpanded = expandedRange?.overlaps(group) ?? false
            if groupIndex < collapsibleCount, !isExpanded {
                cells.append(.collapsedGroup(group))
            } else {
                cells += group.map { .photo($0) }
            }
        }
        let ungroupedStart = groups.last?.upperBound ?? 0
        cells += (ungroupedStart ..< photoCount).map { .photo($0) }
        return cells
    }
}
