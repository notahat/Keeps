import SwiftUI

/// One tile on the pick screen: the photo scaled to fit, a focus highlight,
/// and a badge when it's a keeper. Doesn't handle input or know where it
/// sits; PickScreen places it and handles clicks.
struct PickTile: View {
    let item: PhotoItem
    let size: CGSize
    let isFocused: Bool
    let isKeeper: Bool

    var body: some View {
        FramedPhoto(item: item, frameSize: size)
            .selectionHighlight(isSelected: isFocused)
            .overlay(alignment: .topTrailing) {
                if isKeeper {
                    KeeperBadge()
                        .padding(10)
                }
            }
    }
}

/// The size every tile preview uses.
private let previewTileSize = CGSize(width: 300, height: 300)

#Preview("Plain tile") {
    PickTile(item: PreviewPhotos.landscape, size: previewTileSize, isFocused: false, isKeeper: false)
        .padding()
        .background(.black)
}

#Preview("Focused tile") {
    PickTile(item: PreviewPhotos.landscape, size: previewTileSize, isFocused: true, isKeeper: false)
        .padding()
        .background(.black)
}

#Preview("Keeper tile") {
    PickTile(item: PreviewPhotos.portrait, size: previewTileSize, isFocused: false, isKeeper: true)
        .padding()
        .background(.black)
}

#Preview("Focused keeper tile") {
    PickTile(item: PreviewPhotos.portrait, size: previewTileSize, isFocused: true, isKeeper: true)
        .padding()
        .background(.black)
}
