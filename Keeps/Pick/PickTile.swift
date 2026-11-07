import SwiftUI

/// One tile on the pick screen: the photo scaled to fit, a selection
/// highlight, and a badge when it's a keeper. Doesn't handle input or know
/// where it sits; PickScreen places it and handles clicks.
struct PickTile: View {
    let photo: PhotoItem

    /// The tile's size in points.
    let size: CGSize
    let isSelected: Bool
    let isKeeper: Bool

    var body: some View {
        FramedPhoto(photo: photo, frameSize: size)
            .selectionHighlight(isSelected: isSelected)
            .overlay(alignment: .topTrailing) {
                if isKeeper {
                    KeeperBadge()
                        .padding(10)
                }
            }
    }
}

/// The size in points every tile preview uses.
private let previewTileSize = CGSize(width: 300, height: 300)

#Preview("Plain tile") {
    PickTile(photo: PreviewPhotos.landscape, size: previewTileSize, isSelected: false, isKeeper: false)
        .padding()
        .background(.black)
}

#Preview("Selected tile") {
    PickTile(photo: PreviewPhotos.landscape, size: previewTileSize, isSelected: true, isKeeper: false)
        .padding()
        .background(.black)
}

#Preview("Keeper tile") {
    PickTile(photo: PreviewPhotos.portrait, size: previewTileSize, isSelected: false, isKeeper: true)
        .padding()
        .background(.black)
}

#Preview("Selected keeper tile") {
    PickTile(photo: PreviewPhotos.portrait, size: previewTileSize, isSelected: true, isKeeper: true)
        .padding()
        .background(.black)
}
