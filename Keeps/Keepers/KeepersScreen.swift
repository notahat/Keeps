import SwiftUI

/// The keepers screen: the keepers of the done groups as an even grid of
/// tiles, in the same order as the keepers pile, the latest group's first.
/// Arrow and h/j/k/l keys move the selection, and Space or a double-click
/// shows the selected photo full size, where the same keys step through the
/// keepers and Space or Escape goes back to the tiles. Clicking a tile
/// selects it.
///
/// KeepersScreen places the tiles, shows the full-size view over them, and
/// handles input. TileLayout works out where the tiles go, and Grouping
/// holds the keepers. It only shows them: they're changed on the pick
/// screen.
struct KeepersScreen: View {
    let grouping: Grouping

    /// The selected tile, as its index among the keepers.
    @State private var selectedIndex = 0

    /// Whether the selected photo is showing full size, over the tiles.
    @State private var isFullSize = false

    /// The tiles' shape, worked out once when the screen appears so that
    /// nothing moves while it's showing.
    @State private var aspectRatio: CGFloat

    @State private var scrollPosition = ScrollPosition()

    /// How far the tiles are scrolled, tracked so that revealing a tile
    /// scrolls only as far as needed.
    @State private var scrollOffset: CGFloat = 0

    /// Whether the tiles have keyboard focus. They keep it while the
    /// full-size view is up, and handle its keys too.
    @FocusState private var hasKeyboardFocus: Bool

    private static let spacing: CGFloat = 12
    private static let minimumTileLength: CGFloat = 200

    /// Room around the tiles inside the scroll view, so it doesn't clip
    /// the half of the highlight that falls outside the outer tiles.
    private static let edgeRoom: CGFloat = SelectionHighlight.lineWidth

    init(grouping: Grouping) {
        self.grouping = grouping
        let keepers = grouping.keepersOfDoneGroups.map { grouping.items[$0] }
        _aspectRatio = State(initialValue: FramedPhoto.commonAspectRatio(of: keepers))
    }

    var body: some View {
        let keepers = grouping.keepersOfDoneGroups.map { grouping.items[$0] }
        if keepers.isEmpty {
            // Only for a moment: FolderView goes back to the sort screen
            // once there are no keepers.
            Text("No keepers yet.")
                .foregroundStyle(.secondary)
        } else {
            GeometryReader { proxy in
                tiles(of: keepers, in: proxy.size)
            }
            .padding(Self.spacing - Self.edgeRoom)
            .opacity(isFullSize ? 0 : 1)
            .allowsHitTesting(!isFullSize)
            .overlay {
                if isFullSize {
                    fullSize(of: keepers)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isFullSize)
        }
    }

    /// The selected keeper full size, with its place among the keepers.
    private func fullSize(of keepers: [PhotoItem]) -> some View {
        let index = min(selectedIndex, keepers.count - 1)
        return FullSizeImage(items: keepers, index: index)
            .overlay(alignment: .bottomTrailing) {
                PhotoPositionLabel(index: index, count: keepers.count)
                    .padding(12)
            }
            .padding(Self.spacing)
            // Without this, clicking the full-size view would take keyboard
            // focus away from the tiles, and the keys would stop working.
            .onTapGesture { hasKeyboardFocus = true }
    }

    /// The tiles for the keepers, laid out in the given space, scrolling
    /// only when they don't fit.
    private func tiles(of keepers: [PhotoItem], in size: CGSize) -> some View {
        let tileArea = CGSize(width: size.width - 2 * Self.edgeRoom, height: size.height - 2 * Self.edgeRoom)
        let layout = TileLayout(
            tileCount: keepers.count,
            aspectRatio: aspectRatio,
            availableSize: tileArea,
            spacing: Self.spacing,
            minimumTileLength: Self.minimumTileLength
        )
        return ScrollView(.vertical) {
            ZStack(alignment: .topLeading) {
                ForEach(Array(keepers.enumerated()), id: \.element.id) { index, keeper in
                    tile(of: keeper, index: index, frame: layout.tileFrames[index])
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
            handleKeyPress(press, layout: layout, viewportHeight: tileArea.height)
        }
        .onChange(of: isFullSize) { _, isNowFullSize in
            guard !isNowFullSize else { return }
            // At full size, the selection may have moved to a keeper whose
            // tile is scrolled out of view, so it's scrolled back in.
            hasKeyboardFocus = true
            reveal(selectedIndex, layout: layout, viewportHeight: tileArea.height, isAnimated: false)
        }
    }

    /// The tile for a keeper, in its frame, with the selection highlight and
    /// click handling.
    private func tile(of keeper: PhotoItem, index: Int, frame: CGRect) -> some View {
        FramedPhoto(item: keeper, frameSize: frame.size)
            .selectionHighlight(isSelected: index == selectedIndex)
            .contentShape(Rectangle())
            .onClick { _ in
                selectedIndex = index
                hasKeyboardFocus = true
            } onDoubleClick: { _ in
                isFullSize = true
            }
            .position(x: frame.midX, y: frame.midY)
    }

    /// Moves the selection for the movement keys: around the tiles, or one
    /// keeper either way at full size. Space shows or hides the full-size
    /// view, and Escape hides it. Returns whether the key was handled.
    private func handleKeyPress(_ press: KeyPress, layout: TileLayout, viewportHeight: CGFloat) -> Bool {
        let tileCount = layout.tileFrames.count
        if let direction = MoveDirection(press) {
            guard tileCount > 0 else { return true }
            if isFullSize {
                selectedIndex = max(0, min(tileCount - 1, selectedIndex + direction.linearStep))
            } else {
                selectedIndex = layout.target(from: selectedIndex, moving: direction)
                reveal(selectedIndex, layout: layout, viewportHeight: viewportHeight)
            }
            return true
        }
        switch press.key {
        case .space:
            isFullSize.toggle()
        case .escape where isFullSize:
            isFullSize = false
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
}
