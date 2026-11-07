import SwiftUI

/// The pick screen: one group's photos as an even grid of tiles under a
/// quiet header, where the group's keepers are picked. Arrow and h/j/k/l
/// keys move the selection, F toggles keep on the selected photo, Space or a
/// double-click toggles a full-size view of it, Return marks the group done
/// or not done, and Escape leaves the full-size view or goes back to the
/// sort screen. Clicking a tile selects it.
///
/// Once the group is done, only its keepers are tiles, and the photos that
/// weren't kept sit on a pile (SetAsidePile) in the bottom-right corner.
/// Then F does nothing.
///
/// PickScreen draws the tiles (PickTile) in ScrollingTiles, which handles
/// clicks and the movement keys, places the pile, shows FullSizeView over
/// them, and handles the other keys, including the full-size view's.
/// PickArrangement says which photos are tiles, and Grouping holds the open
/// group, its keepers, and the done groups.
struct PickScreen: View {
    let grouping: Grouping
    let group: Range<Int>

    /// Where the full-size view is: hidden, sitting exactly over the selected
    /// tile, or at full size. The view passes through `overTile` on the way
    /// out and back, because the zoom animates from the tile's frame to full
    /// size; appearing straight at full size would skip the zoom.
    private enum FullSizeState {
        case hidden, overTile, zoomed
    }

    /// The selected tile, as its index among the tiles.
    @State private var selectedIndex = 0

    @State private var fullSizeState = FullSizeState.hidden

    /// The tiles' shape, worked out once when the group opens so that
    /// nothing moves while it's open.
    @State private var aspectRatio: CGFloat

    /// Whether the tiles have keyboard focus. They keep it while the
    /// full-size view is up, and handle its keys too.
    @FocusState private var hasKeyboardFocus: Bool

    /// Pairs each tile with the full-size view, so opening and closing it
    /// zooms between the selected tile and full size.
    @Namespace private var zoomNamespace

    private static let zoomAnimation = Animation.snappy(duration: 0.2)

    private static let spacing = FramedPhoto.gridSpacing

    /// The width and height of the pile of photos that weren't kept.
    private static let pileLength: CGFloat = 220

    init(grouping: Grouping, group: Range<Int>) {
        self.grouping = grouping
        self.group = group
        _aspectRatio = State(initialValue: FramedPhoto.commonAspectRatio(of: grouping.photos[group]))
    }

    /// Which of the group's photos are tiles and which are on the pile.
    private var arrangement: PickArrangement {
        PickArrangement(group: group, keepers: grouping.keepers, isDone: grouping.isDone(group))
    }

    /// The photos at some indices in the folder.
    private func photos(_ photoIndices: [Int]) -> [PhotoItem] {
        photoIndices.map { grouping.photos[$0] }
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
            tilesAndPile
                .opacity(fullSizeState == .zoomed ? 0 : 1)
                .allowsHitTesting(!isFullSize)
                .overlay {
                    if isFullSize {
                        fullSize
                    }
                }
        }
    }

    /// The full-size view, which appears exactly over the selected tile and
    /// zooms out from there.
    private var fullSize: some View {
        let tilePhotos = arrangement.tilePhotos
        return FullSizeView(
            photos: photos(tilePhotos),
            selectedIndex: selectedIndex,
            isKeeper: grouping.keepers.contains(tilePhotos[selectedIndex]),
            isZoomed: fullSizeState == .zoomed,
            zoomNamespace: zoomNamespace
        )
        .padding(Self.spacing)
        // Without this, clicking the full-size view would take keyboard
        // focus away from the tiles, and the keys would stop working.
        .onTapGesture { hasKeyboardFocus = true }
        .onAppear {
            withAnimation(Self.zoomAnimation) { fullSizeState = .zoomed }
        }
    }

    /// The line above the tiles: which group this is among all the groups,
    /// whether it's done, and how many of its photos are kept.
    private var header: some View {
        let groupNumber = grouping.groupNumber(of: group)
        let groupCount = grouping.layout.groups.count
        let keptCount = grouping.keptCount(in: group)
        let doneLabel = grouping.isDone(group) ? "Done · " : ""
        return Text("Group \(groupNumber) of \(groupCount) · \(doneLabel)\(keptCount) of \(group.count) kept")
            .font(.headline)
            .foregroundStyle(.secondary)
            .padding(.top, Self.spacing)
    }

    /// The tiles, with the pile beside them in the bottom-right corner when
    /// there is one.
    private var tilesAndPile: some View {
        let arrangement = arrangement
        let tilePhotos = arrangement.tilePhotos
        return HStack(alignment: .bottom, spacing: 0) {
            ScrollingTiles(
                photos: photos(tilePhotos),
                aspectRatio: aspectRatio,
                selectedIndex: $selectedIndex,
                isFullSize: isFullSize,
                hasKeyboardFocus: $hasKeyboardFocus,
                onDoubleClick: openFullSize,
                handleOtherKey: handleActionKey
            ) { index, size in
                tile(ofPhoto: tilePhotos[index], index: index, size: size)
            }
            if !arrangement.pilePhotos.isEmpty {
                // ScrollingTiles keeps the spacing between the tiles and the
                // pile.
                SetAsidePile(
                    photos: photos(arrangement.pilePhotos),
                    length: Self.pileLength,
                    aspectRatio: aspectRatio
                )
                .padding([.bottom, .trailing], Self.spacing)
            }
        }
    }

    /// The tile for a photo, at the tile at an index among the tiles.
    private func tile(ofPhoto photoIndex: Int, index: Int, size: CGSize) -> some View {
        let photo = grouping.photos[photoIndex]
        return PickTile(
            photo: photo,
            size: size,
            isSelected: index == selectedIndex,
            isKeeper: grouping.keepers.contains(photoIndex)
        )
        // The tile supplies the frame the full-size view zooms out of and
        // back into.
        .matchedGeometryEffect(id: AnyHashable(photo.id), in: zoomNamespace)
    }

    /// Handles the keys that do the same on the tiles and at full size:
    /// F, Space, Return, and Escape. Returns false for any other key.
    private func handleActionKey(_ press: KeyPress) -> Bool {
        if press.isPlain(letter: "f") {
            toggleSelectedKeeper()
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

    /// Marks the selected photo as a keeper, or unmarks it, unless the group
    /// is done.
    private func toggleSelectedKeeper() {
        let tilePhotos = arrangement.tilePhotos
        guard !grouping.isDone(group), tilePhotos.indices.contains(selectedIndex) else { return }
        grouping.toggleKeeper(atPhoto: tilePhotos[selectedIndex])
    }

    /// Marks the group done, which piles up the photos that weren't kept, or
    /// marks a done group not done, which brings them back. The selection
    /// stays on the selected photo, or if it goes onto the pile, moves to
    /// the nearest keeper before it.
    private func toggleDone() {
        let tilePhotos = arrangement.tilePhotos
        let selectedPhoto = tilePhotos.indices.contains(selectedIndex) ? tilePhotos[selectedIndex] : group.lowerBound
        fullSizeState = .hidden
        if grouping.isDone(group) {
            grouping.markOpenGroupNotDone()
        } else {
            grouping.markOpenGroupDone()
        }
        selectedIndex = arrangement.tileIndex(nearestPhoto: selectedPhoto) ?? 0
    }

    /// Puts the full-size view up over the selected tile, when there is one.
    /// It zooms out from there as it appears.
    private func openFullSize() {
        guard arrangement.tilePhotos.indices.contains(selectedIndex) else { return }
        fullSizeState = .overTile
    }

    /// Zooms the full-size view back into the selected tile while the other
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
}
