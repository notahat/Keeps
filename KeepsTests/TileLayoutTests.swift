import CoreGraphics
@testable import Keeps
import Testing

struct TileLayoutTests {
    /// Five square tiles in a 320×210 space with 10-point spacing, which
    /// lays out as a row of three over a centred row of two, 100 points
    /// each.
    private func makeThreeOverTwoLayout() -> TileLayout {
        TileLayout(
            tileCount: 5,
            aspectRatio: 1,
            availableSize: CGSize(width: 320, height: 210),
            spacing: 10,
            minimumTileLength: 50
        )
    }

    @Test("A single tile is as large as fits, centred")
    func singleTile() {
        let layout = TileLayout(
            tileCount: 1,
            aspectRatio: 1.5,
            availableSize: CGSize(width: 900, height: 400),
            spacing: 10,
            minimumTileLength: 50
        )

        #expect(layout.columnCount == 1)
        #expect(layout.tileFrames == [CGRect(x: 150, y: 0, width: 600, height: 400)])
    }

    @Test("The column count giving the largest tiles wins")
    func largestTilesWin() {
        let wide = TileLayout(
            tileCount: 4,
            aspectRatio: 1,
            availableSize: CGSize(width: 1000, height: 250),
            spacing: 10,
            minimumTileLength: 50
        )
        let tall = TileLayout(
            tileCount: 4,
            aspectRatio: 1,
            availableSize: CGSize(width: 250, height: 1000),
            spacing: 10,
            minimumTileLength: 50
        )

        #expect(wide.columnCount == 4)
        #expect(tall.columnCount == 1)
    }

    @Test("A short last row is centred")
    func shortLastRowCentred() {
        let layout = makeThreeOverTwoLayout()

        #expect(layout.columnCount == 3)
        #expect(layout.tileFrames == [
            CGRect(x: 0, y: 0, width: 100, height: 100),
            CGRect(x: 110, y: 0, width: 100, height: 100),
            CGRect(x: 220, y: 0, width: 100, height: 100),
            CGRect(x: 55, y: 110, width: 100, height: 100),
            CGRect(x: 165, y: 110, width: 100, height: 100),
        ])
    }

    @Test("Tiles that fit don't scroll")
    func fittingTilesDoNotScroll() {
        let layout = makeThreeOverTwoLayout()

        #expect(!layout.isScrollable)
    }

    @Test("Tiles stop shrinking at the minimum size, fill the width, and scroll")
    func minimumSizeScrolls() {
        let layout = TileLayout(
            tileCount: 20,
            aspectRatio: 1,
            availableSize: CGSize(width: 300, height: 300),
            spacing: 0,
            minimumTileLength: 90
        )

        #expect(layout.columnCount == 3)
        #expect(layout.tileSize == CGSize(width: 100, height: 100))
        #expect(layout.contentSize == CGSize(width: 300, height: 700))
        #expect(layout.isScrollable)
    }

    @Test("The minimum size applies to a portrait tile's height")
    func minimumSizeForPortrait() {
        let layout = TileLayout(
            tileCount: 20,
            aspectRatio: 0.5,
            availableSize: CGSize(width: 300, height: 300),
            spacing: 0,
            minimumTileLength: 200
        )

        #expect(layout.columnCount == 3)
        #expect(layout.tileSize == CGSize(width: 100, height: 200))
    }

    @Test("No tiles lay out as nothing")
    func noTiles() {
        let layout = TileLayout(
            tileCount: 0,
            aspectRatio: 1,
            availableSize: CGSize(width: 300, height: 300),
            spacing: 10,
            minimumTileLength: 50
        )

        #expect(layout.tileFrames.isEmpty)
        #expect(!layout.isScrollable)
    }

    @Test("h and l move to the previous and next tile, stopping at the ends")
    func leftAndRight() {
        let layout = makeThreeOverTwoLayout()

        #expect(layout.target(from: 2, moving: .right) == 3)
        #expect(layout.target(from: 3, moving: .left) == 2)
        #expect(layout.target(from: 0, moving: .left) == 0)
        #expect(layout.target(from: 4, moving: .right) == 4)
    }

    @Test("j and k move to the nearest tile in the next row")
    func downAndUp() {
        let layout = makeThreeOverTwoLayout()

        #expect(layout.target(from: 0, moving: .down) == 3)
        #expect(layout.target(from: 2, moving: .down) == 4)
        #expect(layout.target(from: 3, moving: .up) == 0)
    }

    @Test("j and k go left when two tiles are equally near")
    func tiesGoLeft() {
        let layout = makeThreeOverTwoLayout()

        #expect(layout.target(from: 1, moving: .down) == 3)
        #expect(layout.target(from: 4, moving: .up) == 1)
    }

    @Test("Stepping one at a time goes to the next tile in order, even moving down")
    func stepForward() {
        let layout = makeThreeOverTwoLayout()

        #expect(layout.stepTarget(from: 2, moving: .down) == 3)
    }

    @Test("Stepping one at a time goes to the previous tile in order, even moving up")
    func stepBack() {
        let layout = makeThreeOverTwoLayout()

        #expect(layout.stepTarget(from: 3, moving: .up) == 2)
    }

    @Test("Stepping one at a time stops at the first tile")
    func stepStopsAtFirst() {
        let layout = makeThreeOverTwoLayout()

        #expect(layout.stepTarget(from: 0, moving: .left) == 0)
    }

    @Test("Stepping one at a time stops at the last tile")
    func stepStopsAtLast() {
        let layout = makeThreeOverTwoLayout()

        #expect(layout.stepTarget(from: 4, moving: .right) == 4)
    }

    @Test("The most common aspect ratio wins, counting near matches as the same")
    func commonAspectRatio() {
        let ratios: [CGFloat] = [0.667, 1.5, 1.4999, 1.333]

        #expect(TileLayout.commonAspectRatio(of: ratios) == 1.5)
    }

    @Test("There is no common aspect ratio without any ratios")
    func noCommonAspectRatio() {
        #expect(TileLayout.commonAspectRatio(of: []) == nil)
    }

    @Test("Revealing a tile below the view scrolls just far enough to show it")
    func revealBelow() {
        let layout = makeScrollingLayout()

        let offset = layout.scrollOffset(revealing: 9, from: 0, viewportHeight: 300)

        #expect(offset == 100)
    }

    @Test("Revealing a tile above the view scrolls up to its top")
    func revealAbove() {
        let layout = makeScrollingLayout()

        let offset = layout.scrollOffset(revealing: 0, from: 250, viewportHeight: 300)

        #expect(offset == 0)
    }

    @Test("Revealing a tile already in view doesn't scroll")
    func revealInView() {
        let layout = makeScrollingLayout()

        let offset = layout.scrollOffset(revealing: 3, from: 0, viewportHeight: 300)

        #expect(offset == nil)
    }

    /// Twenty 100-point square tiles, three across with no spacing, so
    /// tile 9 starts the fourth row, 300 to 400 points down.
    private func makeScrollingLayout() -> TileLayout {
        TileLayout(
            tileCount: 20,
            aspectRatio: 1,
            availableSize: CGSize(width: 300, height: 300),
            spacing: 0,
            minimumTileLength: 90
        )
    }

    @Test("j and k stay put with no row to move to")
    func noRowToMoveTo() {
        let layout = makeThreeOverTwoLayout()

        #expect(layout.target(from: 3, moving: .down) == 3)
        #expect(layout.target(from: 1, moving: .up) == 1)
    }
}
