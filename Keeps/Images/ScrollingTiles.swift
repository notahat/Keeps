import SwiftUI

/// Photos as an even grid of tiles, one of them selected, scrolling only
/// when the tiles don't fit: the tiles of the pick and keepers screens.
///
/// ScrollingTiles lays the tiles out with TileLayout, places the tile view
/// the screen draws for each photo, and handles the input the two screens
/// share. A click selects a tile and takes keyboard focus. The movement
/// keys move the selection around the grid, scrolling just far enough to
/// keep it in view, or one photo either way while the screen's full-size
/// view is up. Every other key, and what a double click does, is left to
/// the screen. The tiles sit the grid spacing in from every edge.
///
/// It doesn't show the full-size view: the screen lays that over the tiles.
/// The tiles keep keyboard focus while it's up, so they go on handling the
/// keys, and the screen hands focus back to them if the full-size view is
/// clicked. When the full-size view goes, the selected tile is scrolled
/// back into view, since stepping at full size may have moved the
/// selection to a tile out of sight.
struct ScrollingTiles<Tile: View>: View {
    let photos: [PhotoItem]

    /// Each tile's width over its height (see FramedPhoto.commonAspectRatio).
    let aspectRatio: CGFloat

    /// The selected tile, as an index into `photos`.
    @Binding var selectedIndex: Int

    /// Whether the screen's full-size view is up over the tiles.
    let isFullSize: Bool

    /// Whether the tiles have keyboard focus. The screen shares it so it can
    /// give focus back to the tiles.
    let hasKeyboardFocus: FocusState<Bool>.Binding

    /// Called on a double click on a tile, once the click has selected it.
    let onDoubleClick: () -> Void

    /// Handles a key that isn't a movement key, and returns whether it did.
    let handleOtherKey: (KeyPress) -> Bool

    /// Draws the tile for the photo at an index into `photos`, at a size in
    /// points. ScrollingTiles positions it and handles its clicks.
    let makeTile: (Int, CGSize) -> Tile

    /// Where the scroll view is told to scroll, to reveal a tile.
    @State private var scrollPosition = ScrollPosition()

    /// How far the tiles are scrolled, in points, tracked so that revealing
    /// a tile scrolls only as far as needed.
    @State private var scrollOffset: CGFloat = 0

    /// The smallest a tile's longer side may be, in points, before the
    /// tiles scroll instead of shrinking.
    private static var minimumTileLength: CGFloat {
        200
    }

    /// Room around the tiles inside the scroll view, in points, so it
    /// doesn't clip the half of the selection highlight that falls outside
    /// the outer tiles. The scroll view is padded by this much less than the
    /// grid spacing, so the tiles themselves sit the grid spacing in.
    private static var edgeRoom: CGFloat {
        SelectionHighlight.lineWidth
    }

    /// Make the tiles for some photos. Each parameter is described on the
    /// property of the same name.
    init(
        photos: [PhotoItem],
        aspectRatio: CGFloat,
        selectedIndex: Binding<Int>,
        isFullSize: Bool,
        hasKeyboardFocus: FocusState<Bool>.Binding,
        onDoubleClick: @escaping () -> Void,
        handleOtherKey: @escaping (KeyPress) -> Bool,
        @ViewBuilder makeTile: @escaping (Int, CGSize) -> Tile
    ) {
        self.photos = photos
        self.aspectRatio = aspectRatio
        _selectedIndex = selectedIndex
        self.isFullSize = isFullSize
        self.hasKeyboardFocus = hasKeyboardFocus
        self.onDoubleClick = onDoubleClick
        self.handleOtherKey = handleOtherKey
        self.makeTile = makeTile
    }

    var body: some View {
        GeometryReader { proxy in
            tiles(in: proxy.size)
        }
        .padding(FramedPhoto.gridSpacing - Self.edgeRoom)
    }

    /// Lay the tiles out in the given space, in a scroll view that scrolls
    /// only when they don't fit.
    private func tiles(in size: CGSize) -> some View {
        let tileArea = CGSize(width: size.width - 2 * Self.edgeRoom, height: size.height - 2 * Self.edgeRoom)
        let layout = TileLayout(
            tileCount: photos.count,
            aspectRatio: aspectRatio,
            availableSize: tileArea,
            spacing: FramedPhoto.gridSpacing,
            minimumTileLength: Self.minimumTileLength
        )
        return ScrollView(.vertical) {
            ZStack(alignment: .topLeading) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, _ in
                    tile(at: index, frame: layout.tileFrames[index])
                }
            }
            .frame(width: layout.contentSize.width, height: layout.contentSize.height)
            .padding(Self.edgeRoom)
        }
        .scrollDisabled(!layout.isScrollable)
        .scrollPosition($scrollPosition)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, offset in
            scrollOffset = offset
        }
        .handlesKeys(hasKeyboardFocus: hasKeyboardFocus) { press in
            // Tiles are revealed within the tile area rather than the whole
            // scroll view, which leaves the edge room above and below for
            // the highlight, so it isn't cut off.
            handleKeyPress(press, layout: layout, viewportHeight: tileArea.height)
        }
        .onChange(of: isFullSize) { _, isNowFullSize in
            guard !isNowFullSize else { return }
            hasKeyboardFocus.wrappedValue = true
            reveal(selectedIndex, layout: layout, viewportHeight: tileArea.height, isAnimated: false)
        }
    }

    /// Place the screen's tile for the photo at an index in its frame, with
    /// click handling.
    private func tile(at index: Int, frame: CGRect) -> some View {
        makeTile(index, frame.size)
            .contentShape(Rectangle())
            .onClick { _ in
                selectedIndex = index
                hasKeyboardFocus.wrappedValue = true
            } onDoubleClick: { _ in
                onDoubleClick()
            }
            .position(x: frame.midX, y: frame.midY)
    }

    /// Move the selection for a movement key: around the grid, or one photo
    /// either way at full size. Pass any other key to handleOtherKey.
    /// Return whether the key was handled.
    private func handleKeyPress(_ press: KeyPress, layout: TileLayout, viewportHeight: CGFloat) -> Bool {
        guard let direction = MoveDirection(press) else { return handleOtherKey(press) }
        guard !photos.isEmpty else { return true }
        if isFullSize {
            selectedIndex = layout.stepTarget(from: selectedIndex, moving: direction)
        } else {
            selectedIndex = layout.target(from: selectedIndex, moving: direction)
            reveal(selectedIndex, layout: layout, viewportHeight: viewportHeight)
        }
        return true
    }

    /// Scroll just far enough to bring a tile fully into view.
    private func reveal(_ index: Int, layout: TileLayout, viewportHeight: CGFloat, isAnimated: Bool = true) {
        guard layout.isScrollable,
              let offset = layout.scrollOffset(revealing: index, from: scrollOffset, viewportHeight: viewportHeight)
        else { return }
        if isAnimated {
            withAnimation { scrollPosition.scrollTo(y: offset) }
        } else {
            scrollPosition.scrollTo(y: offset)
        }
    }
}
