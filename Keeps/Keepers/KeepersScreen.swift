import SwiftUI

/// The keepers screen: the keepers of the done groups as an even grid of
/// tiles, in the same order as the keepers pile, the latest group's first.
/// Arrow and h/j/k/l keys move the selection, and Space or a double-click
/// shows the selected photo full size, where the same keys step through the
/// keepers and Space or Escape goes back to the tiles. Clicking a tile
/// selects it.
///
/// KeepersScreen draws the tiles in ScrollingTiles, which handles clicks
/// and the movement keys, and shows the full-size view over them. Grouping
/// holds the keepers. It only shows them: they're changed on the pick
/// screen.
struct KeepersScreen: View {
    let grouping: Grouping

    /// The selected tile, as its index among the keepers.
    @State private var selectedIndex = 0

    /// Whether the selected photo is showing full size, over the tiles.
    @State private var isFullSize = false

    /// The tiles' shape, worked out once when the screen is first built so
    /// that nothing moves while it's showing.
    @State private var aspectRatio: CGFloat

    /// Whether the tiles have keyboard focus. They keep it while the
    /// full-size view is up, and handle its keys too.
    @FocusState private var hasKeyboardFocus: Bool

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
            ScrollingTiles(
                photos: keepers,
                aspectRatio: aspectRatio,
                selectedIndex: $selectedIndex,
                isFullSize: isFullSize,
                hasKeyboardFocus: $hasKeyboardFocus,
                onDoubleClick: { isFullSize = true },
                handleOtherKey: handleKeyPress
            ) { index, size in
                FramedPhoto(item: keepers[index], frameSize: size)
                    .selectionHighlight(isSelected: index == selectedIndex)
            }
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
        FullSizeImage(items: keepers, index: selectedIndex)
            .overlay(alignment: .bottomTrailing) {
                PhotoPositionLabel(index: selectedIndex, count: keepers.count)
                    .padding(12)
            }
            .padding(FramedPhoto.gridSpacing)
            // Without this, clicking the full-size view would take keyboard
            // focus away from the tiles, and the keys would stop working.
            .onTapGesture { hasKeyboardFocus = true }
    }

    /// Show or hide the full-size view for Space, and hide it for Escape.
    /// Return whether the key was handled.
    private func handleKeyPress(_ press: KeyPress) -> Bool {
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
}
