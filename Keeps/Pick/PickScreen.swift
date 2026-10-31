import SwiftUI

/// The pick screen: one group's photos as an even grid of tiles under a
/// quiet header, where the group's keepers are picked. Arrow and h/j/k/l
/// keys move focus, F toggles keep on the focused photo, Space or a
/// double-click toggles a full-size view of it, Return marks the group done,
/// and Escape leaves the full-size view or goes back to the sort screen.
/// Clicking a tile focuses it.
///
/// Once the group is done, only its keepers are tiles, and the photos that
/// weren't kept sit on a pile (SetAsidePile) in the bottom-right corner.
/// Then F and Return do nothing.
///
/// Places the tiles (PickTile) and the pile, shows FullSizeView over them,
/// and handles input, including the full-size view's. The layout is
/// TileLayout's, which photos are tiles is PickArrangement's, and the open
/// group, keepers, and done groups are Grouping's. Tiles scale up the sort
/// screen's thumbnails rather than loading larger images.
struct PickScreen: View {
    let grouping: Grouping
    let group: Range<Int>

    /// Where the full-size view is: down, sitting exactly over the focused
    /// tile (as it starts zooming out or finishes zooming back in), or at
    /// full size.
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
    @State private var scrollOffset: CGFloat = 0
    @FocusState private var isFocused: Bool

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
    private static let edgeRoom: CGFloat = PickTile.highlightWidth

    /// Used when none of the group's thumbnails have loaded yet: the shape
    /// of most camera sensors.
    private static let fallbackAspectRatio: CGFloat = 1.5

    init(grouping: Grouping, group: Range<Int>) {
        self.grouping = grouping
        self.group = group
        _aspectRatio = State(initialValue: Self.tileAspectRatio(of: grouping.items[group]))
    }

    /// Which of the group's photos are tiles and which are on the pile.
    private var arrangement: PickArrangement {
        let keeperPlaces = grouping.keepers.filter(group.contains).map { $0 - group.lowerBound }
        return PickArrangement(
            photoCount: group.count,
            keeperPlaces: Set(keeperPlaces),
            isDone: grouping.isDone(group)
        )
    }

    /// The photos at some places in the group.
    private func photos(atPlaces places: [Int]) -> [PhotoItem] {
        places.map { grouping.items[group.lowerBound + $0] }
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
            // them, and the tiles keep keyboard focus throughout, handling
            // the full-size view's keys too. Moving focus to the full-size
            // view from code doesn't take: keys then reach nothing until
            // it's clicked.
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
        let arrangement = arrangement
        let place = arrangement.tilePlaces[focusedIndex]
        return FullSizeView(
            photos: photos(atPlaces: arrangement.tilePlaces),
            focusedIndex: focusedIndex,
            isKeeper: grouping.keepers.contains(group.lowerBound + place),
            isZoomed: fullSizeState == .zoomed,
            zoomNamespace: zoomNamespace
        )
        .padding(Self.edgeRoom)
        // A click would otherwise leave the tiles without focus.
        .onTapGesture { isFocused = true }
        .onAppear {
            withAnimation(Self.zoomAnimation) { fullSizeState = .zoomed }
        }
    }

    /// Which group this is among the closed groups, whether it's done, and
    /// how many of its photos are kept.
    private var header: some View {
        let groups = grouping.layout.groups
        let number = (groups.firstIndex(of: group) ?? 0) + 1
        let keptCount = group.count { grouping.keepers.contains($0) }
        let done = grouping.isDone(group) ? "Done · " : ""
        return Text("Group \(number) of \(groups.count) · \(done)\(keptCount) of \(group.count) kept")
            .font(.headline)
            .foregroundStyle(.secondary)
            .padding(.top, Self.spacing)
    }

    /// The tiles in the given space, with the pile beside them in the
    /// bottom-right corner when there is one.
    private func tilesAndPile(in size: CGSize) -> some View {
        let arrangement = arrangement
        let hasPile = !arrangement.pilePlaces.isEmpty
        let pileRoom = hasPile ? Self.pileLength + Self.spacing : 0
        let tilesSize = CGSize(width: max(0, size.width - pileRoom), height: size.height)
        return HStack(alignment: .bottom, spacing: Self.spacing - 2 * Self.edgeRoom) {
            tiles(atPlaces: arrangement.tilePlaces, in: tilesSize)
                .frame(width: tilesSize.width, height: tilesSize.height)
            if hasPile {
                SetAsidePile(
                    photos: photos(atPlaces: arrangement.pilePlaces),
                    length: Self.pileLength,
                    aspectRatio: aspectRatio
                )
                .padding(Self.edgeRoom)
            }
        }
    }

    /// The tiles for some of the group's photos, laid out in the given
    /// space, scrolling only when they don't fit.
    private func tiles(atPlaces places: [Int], in size: CGSize) -> some View {
        let tileArea = CGSize(width: size.width - 2 * Self.edgeRoom, height: size.height - 2 * Self.edgeRoom)
        let layout = TileLayout(
            tileCount: places.count,
            aspectRatio: aspectRatio,
            availableSize: tileArea,
            spacing: Self.spacing,
            minimumTileLength: Self.minimumTileLength
        )
        return ScrollView(.vertical) {
            ZStack(alignment: .topLeading) {
                ForEach(Array(places.enumerated()), id: \.element) { index, place in
                    tile(atPlace: place, index: index, layout: layout)
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
        .handlesKeys(isFocused: $isFocused) { press in
            // The tile area's height: with the edge room above and below,
            // a tile revealed within it keeps its highlight in view.
            handleKeyPress(press, layout: layout, viewportHeight: tileArea.height)
        }
        .onChange(of: isFullSize) { _, isNowFullSize in
            guard !isNowFullSize else { return }
            // Back from full size, where focus may have moved to a photo
            // that's scrolled out of view.
            isFocused = true
            reveal(focusedIndex, layout: layout, viewportHeight: tileArea.height, isAnimated: false)
        }
    }

    /// The tile for the photo at a place in the group, placed where the
    /// layout puts the tile at an index.
    private func tile(atPlace place: Int, index: Int, layout: TileLayout) -> some View {
        let frame = layout.tileFrames[index]
        let photoIndex = group.lowerBound + place
        let photo = grouping.items[photoIndex]
        return PickTile(
            item: photo,
            size: frame.size,
            isFocused: index == focusedIndex,
            isKeeper: grouping.keepers.contains(photoIndex)
        )
        // Supplies the frame the full-size view zooms out of and back into.
        .matchedGeometryEffect(id: AnyHashable(photo.id), in: zoomNamespace)
        .contentShape(Rectangle())
        // The single click is simultaneous rather than a second tap
        // gesture, which would wait out the double-click time and make
        // focus lag.
        .onTapGesture(count: 2) {
            openFullSize()
        }
        .simultaneousGesture(TapGesture().onEnded {
            focusedIndex = index
            isFocused = true
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
            markDone()
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
        guard !grouping.isDone(group) else { return }
        // Until the group is done, every photo is a tile, so the focused
        // tile's index is its place in the group.
        grouping.toggleKeeper(atPhoto: group.lowerBound + focusedIndex)
    }

    /// Marks the group done, which piles up the photos that weren't kept.
    /// Focus stays on the focused photo if it's a keeper, and otherwise
    /// goes to the nearest keeper before it.
    private func markDone() {
        guard !grouping.isDone(group) else { return }
        // Until now every photo was a tile, so the index is the place.
        let focusedPlace = focusedIndex
        fullSizeState = .hidden
        grouping.markOpenGroupDone()
        focusedIndex = arrangement.tileIndex(nearestPlace: focusedPlace) ?? 0
    }

    /// Puts the full-size view up over the focused tile, when there is one.
    /// It zooms out from there as it appears.
    private func openFullSize() {
        guard arrangement.tilePlaces.indices.contains(focusedIndex) else { return }
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
    /// fallback when none are cached.
    private static func tileAspectRatio(of photos: ArraySlice<PhotoItem>) -> CGFloat {
        let ratios = photos.compactMap { photo -> CGFloat? in
            guard let size = ImagePipeline.shared.cachedImage(for: photo, size: ThumbnailImage.imageSize)?.size,
                  size.height > 0
            else { return nil }
            return size.width / size.height
        }
        return TileLayout.commonAspectRatio(of: ratios) ?? fallbackAspectRatio
    }
}
