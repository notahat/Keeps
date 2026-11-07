import CoreGraphics
@testable import Keeps
import Testing

struct TileLayoutTests {
    /// Make five square tiles in a 320×210 space with 10-point spacing,
    /// which lays out as a row of three over a centred row of two, 100
    /// points each.
    private func makeThreeOverTwoLayout() -> TileLayout {
        TileLayout(
            tileCount: 5,
            aspectRatio: 1,
            availableSize: CGSize(width: 320, height: 210),
            spacing: 10,
            minimumTileLength: 50
        )
    }

    /// Make twenty 100-point square tiles, three across with no spacing, so
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

    @Test("A single tile is as large as fits, centred")
    func singleTile() {
        let layout = TileLayout(
            tileCount: 1,
            aspectRatio: 1.5,
            availableSize: CGSize(width: 900, height: 400),
            spacing: 10,
            minimumTileLength: 50
        )

        #expect(layout.tileFrames == [CGRect(x: 150, y: 0, width: 600, height: 400)])
    }

    @Test("In a wide space, one row gives the largest tiles")
    func wideSpaceUsesOneRow() {
        let layout = TileLayout(
            tileCount: 4,
            aspectRatio: 1,
            availableSize: CGSize(width: 1000, height: 250),
            spacing: 10,
            minimumTileLength: 50
        )

        #expect(layout.columnCount == 4)
    }

    @Test("In a tall space, one column gives the largest tiles")
    func tallSpaceUsesOneColumn() {
        let layout = TileLayout(
            tileCount: 4,
            aspectRatio: 1,
            availableSize: CGSize(width: 250, height: 1000),
            spacing: 10,
            minimumTileLength: 50
        )

        #expect(layout.columnCount == 1)
    }

    @Test("A short last row is centred")
    func shortLastRowCentred() {
        let layout = makeThreeOverTwoLayout()

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

    @Test("Tiles stop shrinking at the minimum size, and stretch to fill the width")
    func minimumSizeFillsWidth() {
        let layout = makeScrollingLayout()

        #expect(layout.tileSize == CGSize(width: 100, height: 100))
    }

    @Test("Tiles at the minimum size that don't fit scroll")
    func minimumSizeScrolls() {
        let layout = makeScrollingLayout()

        #expect(layout.isScrollable)
    }

    @Test("Tiles that scroll make the content tall enough to hold them")
    func scrollingContentHoldsTiles() {
        let layout = makeScrollingLayout()

        #expect(layout.contentSize == CGSize(width: 300, height: 700))
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

        #expect(layout.tileSize == CGSize(width: 100, height: 200))
    }

    @Test("No tiles have no frames")
    func noTiles() {
        let layout = TileLayout(
            tileCount: 0,
            aspectRatio: 1,
            availableSize: CGSize(width: 300, height: 300),
            spacing: 10,
            minimumTileLength: 50
        )

        #expect(layout.tileFrames.isEmpty)
    }

    @Test("No tiles don't scroll")
    func noTilesDoNotScroll() {
        let layout = TileLayout(
            tileCount: 0,
            aspectRatio: 1,
            availableSize: CGSize(width: 300, height: 300),
            spacing: 10,
            minimumTileLength: 50
        )

        #expect(!layout.isScrollable)
    }

    @Test(
        "Left and right move to the previous and next tile, across rows",
        arguments: [(from: 2, direction: MoveDirection.right, to: 3), (from: 3, direction: .left, to: 2)]
    )
    func leftAndRight(from: Int, direction: MoveDirection, to: Int) {
        let layout = makeThreeOverTwoLayout()

        #expect(layout.target(from: from, moving: direction) == to)
    }

    @Test(
        "Left and right stop at the first and last tiles",
        arguments: [(from: 0, direction: MoveDirection.left), (from: 4, direction: .right)]
    )
    func leftAndRightStopAtEnds(from: Int, direction: MoveDirection) {
        let layout = makeThreeOverTwoLayout()

        #expect(layout.target(from: from, moving: direction) == from)
    }

    @Test(
        "Up and down move to the nearest tile in the next row",
        arguments: [
            (from: 0, direction: MoveDirection.down, to: 3),
            (from: 2, direction: .down, to: 4),
            (from: 3, direction: .up, to: 0),
        ]
    )
    func downAndUp(from: Int, direction: MoveDirection, to: Int) {
        let layout = makeThreeOverTwoLayout()

        #expect(layout.target(from: from, moving: direction) == to)
    }

    @Test(
        "Up and down go left when two tiles are equally near",
        arguments: [(from: 1, direction: MoveDirection.down, to: 3), (from: 4, direction: .up, to: 1)]
    )
    func tiesGoLeft(from: Int, direction: MoveDirection, to: Int) {
        let layout = makeThreeOverTwoLayout()

        #expect(layout.target(from: from, moving: direction) == to)
    }

    @Test(
        "Up and down stay put with no row to move to",
        arguments: [(from: 3, direction: MoveDirection.down), (from: 1, direction: .up)]
    )
    func noRowToMoveTo(from: Int, direction: MoveDirection) {
        let layout = makeThreeOverTwoLayout()

        #expect(layout.target(from: from, moving: direction) == from)
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

    @Test("The most common aspect ratio wins, counting near matches as the same")
    func commonAspectRatio() {
        let ratios: [CGFloat] = [0.667, 1.5, 1.4999, 1.333]

        #expect(TileLayout.commonAspectRatio(of: ratios) == 1.5)
    }

    @Test("There is no common aspect ratio without any ratios")
    func noCommonAspectRatio() {
        #expect(TileLayout.commonAspectRatio(of: []) == nil)
    }
}
