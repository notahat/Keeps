import SwiftUI

/// The pick screen: one group's photos as an even grid of tiles under a
/// quiet header, where the group's keepers are picked. Arrow and h/j/k/l
/// keys move focus, F toggles keep on the focused photo, Space or a
/// double-click toggles a full-size view of it, Return marks the group done
/// and moves on to the next, and Escape leaves the full-size view or goes
/// back to the sort screen. Clicking a tile focuses it.
///
/// Draws the tiles, switches to PhotoDetailSurface for full size, and
/// handles input. The layout is TileLayout's, and the open group, keepers,
/// and done groups are Grouping's. Tiles scale up the sort screen's
/// thumbnails rather than loading larger images.
struct PickScreen: View {
    let grouping: Grouping
    let group: Range<Int>

    /// The focused photo, as an index into the group.
    @State private var focusedIndex = 0

    /// Whether the focused photo is shown full size in place of the tiles.
    @State private var isFullSize = false

    /// The tiles' shape, worked out once when the group opens so that
    /// nothing moves while it's open.
    @State private var aspectRatio: CGFloat

    @State private var scrollPosition = ScrollPosition()
    @State private var scrollOffset: CGFloat = 0
    @FocusState private var isFocused: Bool

    private static let spacing: CGFloat = 12
    private static let minimumTileLength: CGFloat = 200

    /// The focus highlight's line width. It's centred on the tile's edge,
    /// leaving a little space between it and the photo.
    fileprivate static let highlightWidth: CGFloat = 3

    /// Room around the tiles inside the scroll view, so it doesn't clip
    /// the half of the highlight that falls outside the outer tiles.
    private static let edgeRoom: CGFloat = highlightWidth

    /// Used when none of the group's thumbnails have loaded yet: the shape
    /// of most camera sensors.
    private static let fallbackAspectRatio: CGFloat = 1.5

    init(grouping: Grouping, group: Range<Int>) {
        self.grouping = grouping
        self.group = group
        _aspectRatio = State(initialValue: Self.tileAspectRatio(of: grouping.items[group]))
    }

    private var photos: ArraySlice<PhotoItem> {
        grouping.items[group]
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
                tiles(in: proxy.size)
            }
            .padding(Self.spacing - Self.edgeRoom)
            .opacity(isFullSize ? 0 : 1)
            .allowsHitTesting(!isFullSize)
            .overlay {
                if isFullSize {
                    fullSize
                        .padding(Self.edgeRoom)
                        // A click would otherwise leave the tiles without
                        // focus.
                        .onTapGesture { isFocused = true }
                }
            }
        }
    }

    /// The focused photo full size, stepping through the group in order,
    /// with its keeper badge and its place in the group.
    private var fullSize: some View {
        PhotoDetailSurface(items: Array(photos), selectedIndex: focusedIndex) { _ in
            ZStack {
                if grouping.keepers.contains(group.lowerBound + focusedIndex) {
                    KeeperBadge(size: 40)
                        .padding(12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
                Text("\(focusedIndex + 1) / \(photos.count)")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .allowsHitTesting(false)
        }
    }

    /// Which group this is among the closed groups, and how many of its
    /// photos are kept.
    private var header: some View {
        let groups = grouping.layout.groups
        let number = (groups.firstIndex(of: group) ?? 0) + 1
        let keptCount = group.count { grouping.keepers.contains($0) }
        return Text("Group \(number) of \(groups.count) · \(keptCount) of \(group.count) kept")
            .font(.headline)
            .foregroundStyle(.secondary)
            .padding(.top, Self.spacing)
    }

    /// The tiles laid out in the given space, scrolling only when they
    /// don't fit.
    private func tiles(in size: CGSize) -> some View {
        let tileArea = CGSize(width: size.width - 2 * Self.edgeRoom, height: size.height - 2 * Self.edgeRoom)
        let layout = TileLayout(
            tileCount: photos.count,
            aspectRatio: aspectRatio,
            availableSize: tileArea,
            spacing: Self.spacing,
            minimumTileLength: Self.minimumTileLength
        )
        return ScrollView(.vertical) {
            ZStack(alignment: .topLeading) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    tile(for: photo, at: index, layout: layout)
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
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress { press in
            // The tile area's height: with the edge room above and below,
            // a tile revealed within it keeps its highlight in view.
            handleKeyPress(press, layout: layout, viewportHeight: tileArea.height) ? .handled : .ignored
        }
        .onAppear {
            isFocused = true
        }
        .onChange(of: isFullSize) { _, isNowFullSize in
            guard !isNowFullSize else { return }
            // Back from full size, where focus may have moved to a photo
            // that's scrolled out of view.
            isFocused = true
            reveal(focusedIndex, layout: layout, viewportHeight: tileArea.height, isAnimated: false)
        }
    }

    /// One tile, placed where the layout puts it.
    private func tile(for photo: PhotoItem, at index: Int, layout: TileLayout) -> some View {
        let frame = layout.tileFrames[index]
        return PickTile(
            item: photo,
            size: frame.size,
            isFocused: index == focusedIndex,
            isKeeper: grouping.keepers.contains(group.lowerBound + index)
        )
        .contentShape(Rectangle())
        // The single click is simultaneous rather than a second tap
        // gesture, which would wait out the double-click time and make
        // focus lag.
        .onTapGesture(count: 2) {
            isFullSize = true
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
        if isFullSize {
            focusedIndex = max(0, min(photos.count - 1, focusedIndex + direction.linearStep))
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
            grouping.toggleKeeper(atPhoto: group.lowerBound + focusedIndex)
            return true
        }
        switch press.key {
        case .space:
            isFullSize.toggle()
        case .return:
            grouping.finishOpenGroup()
        case .escape where isFullSize:
            isFullSize = false
        case .escape:
            grouping.closeOpenGroup()
        default:
            return false
        }
        return true
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

/// One tile on the pick screen: the photo scaled to fit, a focus highlight,
/// and a badge when it's a keeper.
private struct PickTile: View {
    let item: PhotoItem
    let size: CGSize
    let isFocused: Bool
    let isKeeper: Bool

    @Environment(\.controlActiveState) private var controlActiveState

    var body: some View {
        ThumbnailImage(item: item, frameSize: size)
            .overlay {
                if isFocused, controlActiveState == .key {
                    Rectangle().stroke(Color.accentColor, lineWidth: PickScreen.highlightWidth)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isKeeper {
                    KeeperBadge()
                        .padding(10)
                }
            }
    }
}

/// A white checkmark on a green circle, marking a keeper.
private struct KeeperBadge: View {
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .green)
            .font(.system(size: size))
            .shadow(radius: 2)
    }
}
