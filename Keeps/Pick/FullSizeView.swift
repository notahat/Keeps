import SwiftUI

/// The pick screen's full-size view of the focused photo, with its keeper
/// badge and its place in the group. Zooms between the focused tile and full
/// size through `zoomNamespace`, which the tiles supply their frames to:
/// until zoomed it takes the focused tile's frame, and once zoomed its own.
/// With Reduce Motion on, it fades in and out where it is instead.
///
/// Draws only. PickScreen controls when it shows and when it's zoomed, and
/// handles its keys, since the tiles keep keyboard focus throughout.
struct FullSizeView: View {
    let photos: [PhotoItem]
    let focusedIndex: Int
    let isKeeper: Bool
    let isZoomed: Bool
    let zoomNamespace: Namespace.ID

    /// The id the view matches once zoomed. No tile has this id, so there's
    /// no tile frame to take on, and the view fills its own space.
    private static let zoomedID = AnyHashable("zoomed")

    @Environment(\.accessibilityReduceMotion) private var isReducingMotion

    var body: some View {
        FullSizeImage(items: photos, index: focusedIndex)
            .overlay(alignment: .topTrailing) {
                if isKeeper {
                    KeeperBadge(size: 40)
                        .padding(12)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                PhotoPositionLabel(index: focusedIndex, count: photos.count)
                    .padding(12)
            }
            // The same inset as the tile's photo, so the photo doesn't jump
            // as it takes over from the tile.
            .padding(FramedPhoto.imageInset)
            .matchedGeometryEffect(
                id: isZoomed || isReducingMotion ? Self.zoomedID : AnyHashable(photos[focusedIndex].id),
                in: zoomNamespace,
                isSource: false
            )
            .opacity(isReducingMotion && !isZoomed ? 0 : 1)
    }
}
