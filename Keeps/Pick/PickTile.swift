import SwiftUI

/// One tile on the pick screen: the photo scaled to fit, a focus highlight,
/// and a badge when it's a keeper. Doesn't handle input or know where it
/// sits; PickScreen places it and handles clicks.
struct PickTile: View {
    let item: PhotoItem
    let size: CGSize
    let isFocused: Bool
    let isKeeper: Bool

    /// The focus highlight's line width. It's centred on the tile's edge,
    /// leaving a little space between it and the photo, so half of it falls
    /// outside the tile.
    static let highlightWidth: CGFloat = 3

    @Environment(\.controlActiveState) private var controlActiveState

    var body: some View {
        ThumbnailImage(item: item, frameSize: size)
            .overlay {
                if isFocused, controlActiveState == .key {
                    Rectangle().stroke(Color.accentColor, lineWidth: Self.highlightWidth)
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
struct KeeperBadge: View {
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .green)
            .font(.system(size: size))
            .shadow(radius: 2)
    }
}
