import SwiftUI

/// The pick screen's full-size view of the focused photo, with its keeper
/// badge and its place in the group. Zooms between the focused tile and full
/// size through `zoomNamespace`, which the tiles supply their frames to:
/// until zoomed it takes the focused tile's frame, and once zoomed its own.
/// With Reduce Motion on, it fades in and out where it is instead.
///
/// Draws only. PickScreen decides when it shows and when it's zoomed, and
/// handles its keys, since the tiles keep keyboard focus throughout.
struct FullSizeView: View {
    let photos: [PhotoItem]
    let focusedIndex: Int
    let isKeeper: Bool
    let isZoomed: Bool
    let zoomNamespace: Namespace.ID

    /// The matched id once zoomed: one no tile has, so the view keeps its
    /// own frame.
    private static let zoomedID = AnyHashable("zoomed")

    @Environment(\.accessibilityReduceMotion) private var isReducingMotion

    var body: some View {
        PhotoDetailSurface(items: photos, selectedIndex: focusedIndex) { _ in
            ZStack {
                if isKeeper {
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
        // The same inset as the tile's thumbnail, so the photo doesn't jump
        // as it takes over from the tile.
        .padding(ThumbnailImage.imageInset)
        .matchedGeometryEffect(
            id: isZoomed || isReducingMotion ? Self.zoomedID : AnyHashable(photos[focusedIndex].id),
            in: zoomNamespace,
            isSource: false
        )
        .opacity(isReducingMotion && !isZoomed ? 0 : 1)
    }
}
