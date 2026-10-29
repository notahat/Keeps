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

        /// Whether this cell is a collapsed group.
        var isCollapsed: Bool {
            if case .collapsedGroup = self {
                true
            } else {
                false
            }
        }

        /// The photos this cell stands for.
        var photoRange: Range<Int> {
            switch self {
            case let .photo(index): index ..< index + 1
            case let .collapsedGroup(range): range
            }
        }
    }

    let photoCount: Int
    let boundaries: Set<Int>
    let groups: [Range<Int>]
    let cells: [Cell]

    /// `collapsedUpTo` is the photo index at which collapsing stops: groups
    /// ending at or before it are collapsed, later ones are open.
    init(photoCount: Int, boundaries: Set<Int>, collapsedUpTo: Int = 0) {
        self.photoCount = photoCount
        self.boundaries = boundaries
        groups = Self.groups(photoCount: photoCount, boundaries: boundaries)
        cells = Self.cells(photoCount: photoCount, groups: groups, collapsedUpTo: collapsedUpTo)
    }

    /// The photo index that a gap between cells corresponds to: the first
    /// photo of the cell after the gap, or the photo count for the gap after
    /// the last cell.
    func photoIndex(forGap gapIndex: Int) -> Int {
        cells.indices.contains(gapIndex) ? cells[gapIndex].photoRange.lowerBound : photoCount
    }

    /// How many photos are folded away inside collapsed groups, not counting
    /// each group's first photo, which its cell shows.
    var hiddenPhotoCount: Int {
        photoCount - cells.count
    }

    /// Whether there is a boundary at the gap before the given cell.
    func hasBoundary(atGap gapIndex: Int) -> Bool {
        gapIndex > 0 && boundaries.contains(photoIndex(forGap: gapIndex))
    }

    /// Whether the boundary at a gap can be toggled. Collapsed groups are
    /// finished, so the gaps on either side of one are locked, as is the gap
    /// before the first cell, where a group always starts.
    func isGapEditable(_ gapIndex: Int) -> Bool {
        guard gapIndex > 0 else { return false }
        let neighbours = [gapIndex - 1, gapIndex].filter { cells.indices.contains($0) }
        return !neighbours.contains { cells[$0].isCollapsed }
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

    /// The grid cells: groups up to the collapse point collapsed, everything
    /// else as individual photos.
    private static func cells(photoCount: Int, groups: [Range<Int>], collapsedUpTo: Int) -> [Cell] {
        var cells: [Cell] = []
        for group in groups {
            if group.upperBound <= collapsedUpTo {
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
