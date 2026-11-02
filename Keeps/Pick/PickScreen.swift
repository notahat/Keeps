import SwiftUI

/// The pick screen: one group's photos as an even grid of tiles under a
/// quiet header, where the group's keepers are picked. Arrow and h/j/k/l
/// keys move focus, F toggles keep on the focused photo, Space or a
/// double-click toggles a full-size view of it, Return marks the group done
/// or not done, and Escape leaves the full-size view or goes back to the
/// sort screen. Clicking a tile focuses it.
///
/// Once the group is done, only its keepers are tiles, and the photos that
/// weren't kept sit on a pile (SetAsidePile) in the bottom-right corner.
/// Then F does nothing.
///
/// PickScreen places the tiles (PickTile) and the pile, shows FullSizeView
/// over them, and handles input, including the full-size view's. TileLayout
/// works out where the tiles go, PickArrangement says which photos are tiles,
/// and Grouping holds the open group, its keepers, and the done groups.
/// Tiles scale up the sort screen's thumbnails rather than loading larger
/// images.
struct PickScreen: View {
    let grouping: Grouping
    let group: Range<Int>

    /// Where the full-size view is: hidden, sitting exactly over the focused
    /// tile, or at full size. The view passes through `overTile` on the way
    /// out and back, because the zoom animates from the tile's frame to full
    /// size; appearing straight at full size would skip the zoom.
    private enum FullSizeState {
        case hidden, overTile, zoomed
    }

    /// The focused tile, as its index among the tiles.
    @State private var focusedIndex = 0

    @State private var fullSizeState = FullSizeState.hidden

    /// The tiles' shape, worked out once when the group opens so that
    /// nothing moves while it's open.
    @State private var aspectRatio: CGFloat

    @State private var scrollPosition = ScrollPosition()

    /// How far the tiles are scrolled, tracked so that revealing a tile
    /// scrolls only as far as needed.
    @State private var scrollOffset: CGFloat = 0

    /// Whether the tiles have keyboard focus. This is separate from which
    /// tile is focused (`focusedIndex`), which is the one highlighted.
    @FocusState private var hasKeyboardFocus: Bool

    /// Pairs each tile with the full-size view, so opening and closing it
    /// zooms between the focused tile and full size.
    @Namespace private var zoomNamespace

    private static let zoomAnimation = Animation.snappy(duration: 0.2)

    private static let spacing: CGFloat = 12
    private static let minimumTileLength: CGFloat = 200

    /// The width and height of the pile of photos that weren't kept.
    private static let pileLength: CGFloat = 220

    /// Room around the tiles inside the scroll view, so it doesn't clip
    /// the half of the highlight that falls outside the outer tiles.
    private static let edgeRoom: CGFloat = SelectionHighlight.lineWidth

    init(grouping: Grouping, group: Range<Int>) {
        self.grouping = grouping
        self.group = group
        _aspectRatio = State(initialValue: Self.tileAspectRatio(of: grouping.items[group]))
    }

    /// Which of the group's photos are tiles and which are on the pile.
    private var arrangement: PickArrangement {
        PickArrangement(group: group, keepers: grouping.keepers, isDone: grouping.isDone(group))
    }

    /// The photos at some indices in the folder.
    private func photos(_ photoIndices: [Int]) -> [PhotoItem] {
        photoIndices.map { grouping.items[$0] }
    }

    /// Whether the full-size view is up, covering the tiles and taking the
    /// movement keys. True for the whole zoom in and out.
    private var isFullSize: Bool {
        fullSizeState != .hidden
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            // The full-size view covers the tiles rather than replacing
            // them, and the tiles keep keyboard focus throughout, so they
            // handle the full-size view's keys too. Giving the full-size
            // view keyboard focus from code doesn't work: SwiftUI ignores
            // it, and keys reach nothing until the user clicks.
            GeometryReader { proxy in
                tilesAndPile(in: proxy.size)
            }
            .padding(Self.spacing - Self.edgeRoom)
            .opacity(fullSizeState == .zoomed ? 0 : 1)
            .allowsHitTesting(!isFullSize)
            .overlay {
                if isFullSize {
                    fullSize
                }
            }
        }
    }

    /// The full-size view, which appears exactly over the focused tile and
    /// zooms out from there.
    private var fullSize: some View {
        let tilePhotos = arrangement.tilePhotos
        return FullSizeView(
            photos: photos(tilePhotos),
            focusedIndex: focusedIndex,
            isKeeper: grouping.keepers.contains(tilePhotos[focusedIndex]),
            isZoomed: fullSizeState == .zoomed,
            zoomNamespace: zoomNamespace
        )
        .padding(Self.edgeRoom)
        // Without this, clicking the full-size view would take keyboard
        // focus away from the tiles, and the keys would stop working.
        .onTapGesture { hasKeyboardFocus = true }
        .onAppear {
            withAnimation(Self.zoomAnimation) { fullSizeState = .zoomed }
        }
    }

    /// The line above the tiles: which group this is among the closed
    /// groups, whether it's done, and how many of its photos are kept.
    private var header: some View {
        let groups = grouping.layout.groups
        let groupNumber = (groups.firstIndex(of: group) ?? 0) + 1
        let keptCount = grouping.keptCount(in: group)
        let doneLabel = grouping.isDone(group) ? "Done · " : ""
        return Text("Group \(groupNumber) of \(groups.count) · \(doneLabel)\(keptCount) of \(group.count) kept")
            .font(.headline)
            .foregroundStyle(.secondary)
            .padding(.top, Self.spacing)
    }

    /// The tiles in the given space, with the pile beside them in the
    /// bottom-right corner when there is one.
    private func tilesAndPile(in size: CGSize) -> some View {
        let arrangement = arrangement
        let hasPile = !arrangement.pilePhotos.isEmpty
        let pileRoom = hasPile ? Self.pileLength + Self.spacing : 0
        let tilesSize = CGSize(width: max(0, size.width - pileRoom), height: size.height)
        return HStack(alignment: .bottom, spacing: Self.spacing - 2 * Self.edgeRoom) {
            tiles(of: arrangement.tilePhotos, in: tilesSize)
                .frame(width: tilesSize.width, height: tilesSize.height)
            if hasPile {
                SetAsidePile(
                    photos: photos(arrangement.pilePhotos),
                    length: Self.pileLength,
                    aspectRatio: aspectRatio
                )
                .padding(Self.edgeRoom)
            }
        }
    }

    /// The tiles for some of the group's photos, laid out in the given
    /// space, scrolling only when they don't fit.
    private func tiles(of photoIndices: [Int], in size: CGSize) -> some View {
        let tileArea = CGSize(width: size.width - 2 * Self.edgeRoom, height: size.height - 2 * Self.edgeRoom)
        let layout = TileLayout(
            tileCount: photoIndices.count,
            aspectRatio: aspectRatio,
            availableSize: tileArea,
            spacing: Self.spacing,
            minimumTileLength: Self.minimumTileLength
        )
        return ScrollView(.vertical) {
            ZStack(alignment: .topLeading) {
                ForEach(Array(photoIndices.enumerated()), id: \.element) { index, photoIndex in
                    tile(ofPhoto: photoIndex, index: index, layout: layout)
                }
            }
            .frame(width: layout.contentSize.width, height: layout.contentSize.height)
            .padding(Self.edgeRoom)
        }
        .scrollDisabled(!layout.needsScrolling)
        .scrollPosition($scrollPosition)
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, offset in
            scrollOffset = offset
        }
        .handlesKeys(hasKeyboardFocus: $hasKeyboardFocus) { press in
            // Tiles are revealed within the tile area rather than the whole
            // scroll view, which leaves the edge room above and below for
            // the highlight, so it isn't cut off.
            handleKeyPress(press, layout: layout, viewportHeight: tileArea.height)
        }
        .onChange(of: isFullSize) { _, isNowFullSize in
            guard !isNowFullSize else { return }
            // At full size, focus may have moved to a photo whose tile is
            // scrolled out of view, so it's scrolled back in.
            hasKeyboardFocus = true
            reveal(focusedIndex, layout: layout, viewportHeight: tileArea.height, isAnimated: false)
        }
    }

    /// The tile for a photo, placed where the layout puts the tile at an
    /// index.
    private func tile(ofPhoto photoIndex: Int, index: Int, layout: TileLayout) -> some View {
        let frame = layout.tileFrames[index]
        let photo = grouping.items[photoIndex]
        return PickTile(
            item: photo,
            size: frame.size,
            isFocused: index == focusedIndex,
            isKeeper: grouping.keepers.contains(photoIndex)
        )
        // The tile supplies the frame the full-size view zooms out of and
        // back into.
        .matchedGeometryEffect(id: AnyHashable(photo.id), in: zoomNamespace)
        .contentShape(Rectangle())
        // The single click is a simultaneous gesture. As a second
        // onTapGesture, it would wait until a double-click was ruled out,
        // and focus would lag behind the click.
        .onTapGesture(count: 2) {
            openFullSize()
        }
        .simultaneousGesture(TapGesture().onEnded {
            focusedIndex = index
            hasKeyboardFocus = true
        })
        .position(x: frame.midX, y: frame.midY)
    }

    /// Moves focus for the movement keys: around the tiles, or one photo
    /// either way at full size. Passes other keys on to handleActionKey.
    private func handleKeyPress(_ press: KeyPress, layout: TileLayout, viewportHeight: CGFloat) -> Bool {
        guard let direction = MoveDirection(press) else { return handleActionKey(press) }
        let tileCount = layout.tileFrames.count
        guard tileCount > 0 else { return true }
        if isFullSize {
            focusedIndex = max(0, min(tileCount - 1, focusedIndex + direction.linearStep))
        } else {
            focusedIndex = layout.target(from: focusedIndex, moving: direction)
            reveal(focusedIndex, layout: layout, viewportHeight: viewportHeight)
        }
        return true
    }

    /// Handles the keys that do the same on the tiles and at full size:
    /// F, Space, Return, and Escape. Returns false for any other key.
    private func handleActionKey(_ press: KeyPress) -> Bool {
        if press.isPlain(letter: "f") {
            toggleFocusedKeeper()
            return true
        }
        switch press.key {
        case .space where isFullSize:
            closeFullSize()
        case .space:
            openFullSize()
        case .return:
            toggleDone()
        case .escape where isFullSize:
            closeFullSize()
        case .escape:
            grouping.closeOpenGroup()
        default:
            return false
        }
        return true
    }

    /// Marks the focused photo as a keeper, or unmarks it, unless the group
    /// is done.
    private func toggleFocusedKeeper() {
        let tilePhotos = arrangement.tilePhotos
        guard !grouping.isDone(group), tilePhotos.indices.contains(focusedIndex) else { return }
        grouping.toggleKeeper(atPhoto: tilePhotos[focusedIndex])
    }

    /// Marks the group done, which piles up the photos that weren't kept, or
    /// marks a done group not done, which brings them back. Focus stays on
    /// the focused photo, or if it goes onto the pile, moves to the nearest
    /// keeper before it.
    private func toggleDone() {
        let tilePhotos = arrangement.tilePhotos
        let focusedPhoto = tilePhotos.indices.contains(focusedIndex) ? tilePhotos[focusedIndex] : group.lowerBound
        fullSizeState = .hidden
        if grouping.isDone(group) {
            grouping.markOpenGroupNotDone()
        } else {
            grouping.markOpenGroupDone()
        }
        focusedIndex = arrangement.tileIndex(nearestPhoto: focusedPhoto) ?? 0
    }

    /// Puts the full-size view up over the focused tile, when there is one.
    /// It zooms out from there as it appears.
    private func openFullSize() {
        guard arrangement.tilePhotos.indices.contains(focusedIndex) else { return }
        fullSizeState = .overTile
    }

    /// Zooms the full-size view back into the focused tile while the other
    /// tiles fade in, and takes it down once it's there.
    private func closeFullSize() {
        withAnimation(Self.zoomAnimation) {
            fullSizeState = .overTile
        } completion: {
            if fullSizeState == .overTile {
                fullSizeState = .hidden
            }
        }
    }

    /// Scrolls just far enough to bring a tile fully into view.
    private func reveal(_ index: Int, layout: TileLayout, viewportHeight: CGFloat, isAnimated: Bool = true) {
        guard layout.needsScrolling,
              let offset = layout.scrollOffset(revealing: index, from: scrollOffset, viewportHeight: viewportHeight)
        else { return }
        if isAnimated {
            withAnimation { scrollPosition.scrollTo(y: offset) }
        } else {
            scrollPosition.scrollTo(y: offset)
        }
    }

    /// The most common shape among the photos' cached thumbnails, or the
    /// typical shape when none are cached.
    private static func tileAspectRatio(of photos: ArraySlice<PhotoItem>) -> CGFloat {
        let ratios = photos.compactMap { photo -> CGFloat? in
            guard let size = ImagePipeline.shared.cachedImage(for: photo, size: ThumbnailImage.imageSize)?.size,
                  size.height > 0
            else { return nil }
            return size.width / size.height
        }
        return TileLayout.commonAspectRatio(of: ratios) ?? ThumbnailImage.typicalAspectRatio
    }
}
