import CoreGraphics

/// Lays out photos as an even grid of tiles, for the pick and keepers
/// screens, and works out where the movement keys go within it. Pure: it
/// holds no state beyond its results and does no drawing.
///
/// The column count is chosen first, as whichever gives the largest tiles,
/// and the tile size follows. The block of tiles is centred in the space,
/// as is a short last row. Tiles stop shrinking at a minimum size; past
/// that, as many columns as fit are stretched to fill the width, and the
/// tiles scroll vertically.
nonisolated struct TileLayout {
    let columnCount: Int
    let tileSize: CGSize

    /// Each tile's frame, in the coordinates of the content.
    let tileFrames: [CGRect]

    /// The size of the content: the available size, or taller when the
    /// tiles scroll.
    let contentSize: CGSize

    /// Whether the tiles are taller than the available space, so they
    /// scroll.
    let isScrollable: Bool

    /// `aspectRatio` is each tile's width over its height.
    /// `minimumTileLength` is the smallest a tile's longer side may be.
    init(
        tileCount: Int,
        aspectRatio: CGFloat,
        availableSize: CGSize,
        spacing: CGFloat,
        minimumTileLength: CGFloat
    ) {
        precondition(aspectRatio > 0, "A tile's aspect ratio must be positive.")
        guard tileCount > 0 else {
            columnCount = 0
            tileSize = .zero
            tileFrames = []
            contentSize = availableSize
            isScrollable = false
            return
        }
        let grid = TileGrid.choose(
            tileCount: tileCount,
            aspectRatio: aspectRatio,
            availableSize: availableSize,
            spacing: spacing,
            minimumTileLength: minimumTileLength
        )
        let blockSize = grid.blockSize
        let contentSize = CGSize(
            width: max(availableSize.width, blockSize.width),
            height: max(availableSize.height, blockSize.height)
        )
        let origin = CGPoint(
            x: (contentSize.width - blockSize.width) / 2,
            y: (contentSize.height - blockSize.height) / 2
        )
        columnCount = grid.columnCount
        tileSize = grid.tileSize
        tileFrames = (0 ..< tileCount).map { grid.frame(ofTile: $0, blockOrigin: origin) }
        self.contentSize = contentSize
        // Allows for rounding, so tiles that fit exactly don't scroll.
        isScrollable = blockSize.height > availableSize.height + 0.5
    }

    /// The tile a movement key goes to from the given tile. Left and right
    /// step through the tiles in order; up and down go to the horizontally
    /// nearest tile in the next row, the left one when two are equally
    /// near. Stays put when there is nowhere to go. The index must be one
    /// of the tiles.
    func target(from index: Int, moving direction: MoveDirection) -> Int {
        let row = index / columnCount
        let midX = tileFrames[index].midX
        return switch direction {
        case .left: max(0, index - 1)
        case .right: min(tileFrames.count - 1, index + 1)
        case .up: nearestTile(inRow: row - 1, toMidX: midX) ?? index
        case .down: nearestTile(inRow: row + 1, toMidX: midX) ?? index
        }
    }

    /// The tile a movement key goes to when the tiles are stepped through
    /// one at a time, as at full size, where there's no grid to move
    /// around: the next tile for right and down, the previous for left and
    /// up. Stays put at either end.
    func stepTarget(from index: Int, moving direction: MoveDirection) -> Int {
        max(0, min(tileFrames.count - 1, index + direction.linearStep))
    }

    /// Where to scroll so a tile is fully in view, moving only as far as
    /// needed, or nil when it already is. The index must be one of the
    /// tiles.
    func scrollOffset(revealing index: Int, from currentOffset: CGFloat, viewportHeight: CGFloat) -> CGFloat? {
        let frame = tileFrames[index]
        if frame.minY < currentOffset {
            return frame.minY
        }
        if frame.maxY > currentOffset + viewportHeight {
            return frame.maxY - viewportHeight
        }
        return nil
    }

    /// The most common of some width-to-height ratios, rounded to two
    /// decimal places so that photos of the same shape match despite
    /// rounding in their pixel sizes. The earliest wins a tie. Nil when
    /// there are none.
    static func commonAspectRatio(of ratios: [CGFloat]) -> CGFloat? {
        let rounded = ratios.map { ($0 * 100).rounded() / 100 }
        let counts = Dictionary(rounded.map { ($0, 1) }, uniquingKeysWith: +)
        return rounded.max { first, second in counts[first, default: 0] < counts[second, default: 0] }
    }

    /// The tile in a row whose centre is horizontally nearest the given
    /// point, the leftmost on a tie, or nil when there is no such row.
    private func nearestTile(inRow row: Int, toMidX midX: CGFloat) -> Int? {
        let firstInRow = row * columnCount
        guard row >= 0, firstInRow < tileFrames.count else { return nil }
        let rowIndices = firstInRow ..< min(tileFrames.count, firstInRow + columnCount)
        return rowIndices.min { first, second in
            abs(tileFrames[first].midX - midX) < abs(tileFrames[second].midX - midX)
        }
    }
}

/// A chosen column count and tile size, and the geometry that follows.
private nonisolated struct TileGrid {
    let tileCount: Int
    let columnCount: Int
    let tileSize: CGSize
    let spacing: CGFloat

    /// The grid with the largest tiles that fit, or, when those would be
    /// below the minimum, minimum-size columns stretched to fill the width.
    static func choose(
        tileCount: Int,
        aspectRatio: CGFloat,
        availableSize: CGSize,
        spacing: CGFloat,
        minimumTileLength: CGFloat
    ) -> TileGrid {
        let minimumWidth = aspectRatio >= 1 ? minimumTileLength : minimumTileLength * aspectRatio
        let fittedWidths = (1 ... tileCount).map { columnCount in
            fittedWidth(columnCount: columnCount, tileCount: tileCount, aspectRatio: aspectRatio,
                        availableSize: availableSize, spacing: spacing)
        }
        // max(by:) keeps the first of equal widths, so fewer columns win ties.
        let bestIndex = fittedWidths.indices.max { first, second in fittedWidths[first] < fittedWidths[second] } ?? 0
        let (columnCount, width) = fittedWidths[bestIndex] >= minimumWidth
            ? (bestIndex + 1, fittedWidths[bestIndex])
            : scrollingColumns(tileCount: tileCount, minimumWidth: minimumWidth,
                               availableWidth: availableSize.width, spacing: spacing)
        return TileGrid(
            tileCount: tileCount,
            columnCount: columnCount,
            tileSize: CGSize(width: width, height: width / aspectRatio),
            spacing: spacing
        )
    }

    /// The widest a tile can be with the given column count while every row
    /// still fits in the available space.
    private static func fittedWidth(
        columnCount: Int,
        tileCount: Int,
        aspectRatio: CGFloat,
        availableSize: CGSize,
        spacing: CGFloat
    ) -> CGFloat {
        let rowCount = (tileCount + columnCount - 1) / columnCount
        let widthThatFitsAcross = (availableSize.width - CGFloat(columnCount - 1) * spacing) / CGFloat(columnCount)
        let heightThatFitsDown = (availableSize.height - CGFloat(rowCount - 1) * spacing) / CGFloat(rowCount)
        return max(0, min(widthThatFitsAcross, heightThatFitsDown * aspectRatio))
    }

    /// As many minimum-width columns as fit across, and the width that
    /// stretches them to fill it.
    private static func scrollingColumns(
        tileCount: Int,
        minimumWidth: CGFloat,
        availableWidth: CGFloat,
        spacing: CGFloat
    ) -> (columnCount: Int, width: CGFloat) {
        let fittingColumnCount = Int((availableWidth + spacing) / (minimumWidth + spacing))
        let columnCount = max(1, min(tileCount, fittingColumnCount))
        let stretchedWidth = (availableWidth - CGFloat(columnCount - 1) * spacing) / CGFloat(columnCount)
        return (columnCount, max(minimumWidth, stretchedWidth))
    }

    /// How many rows the tiles take, counting a short last row.
    private var rowCount: Int {
        (tileCount + columnCount - 1) / columnCount
    }

    /// The size of the whole block of tiles, without any centring.
    var blockSize: CGSize {
        CGSize(
            width: length(of: columnCount, tilesOf: tileSize.width),
            height: length(of: rowCount, tilesOf: tileSize.height)
        )
    }

    /// Where a tile sits, given where the block starts. A short last row is
    /// centred within the block.
    func frame(ofTile index: Int, blockOrigin: CGPoint) -> CGRect {
        let row = index / columnCount
        let column = index % columnCount
        let tilesInRow = min(columnCount, tileCount - row * columnCount)
        let rowInset = (blockSize.width - length(of: tilesInRow, tilesOf: tileSize.width)) / 2
        let origin = CGPoint(
            x: blockOrigin.x + rowInset + CGFloat(column) * (tileSize.width + spacing),
            y: blockOrigin.y + CGFloat(row) * (tileSize.height + spacing)
        )
        return CGRect(origin: origin, size: tileSize)
    }

    /// The length of a line of tiles with spacing between them.
    private func length(of count: Int, tilesOf tileLength: CGFloat) -> CGFloat {
        CGFloat(count) * tileLength + CGFloat(max(0, count - 1)) * spacing
    }
}
