import SwiftUI
import AppKit

/// A fixed-size square cell that loads and displays a photo thumbnail.
/// Shows a neutral placeholder while loading. Uses .task(id:) so the load
/// is automatically cancelled if the cell scrolls out of view.
struct ThumbnailView: View {
    let item: PhotoItem

    // Request at 2x the display size for Retina screens.
    private static let displaySize: Int = 200
    private static let pixelSize: Int = displaySize * 2

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(nsColor: .quaternaryLabelColor)
            }
        }
        .frame(width: CGFloat(Self.displaySize), height: CGFloat(Self.displaySize))
        .clipped()
        .task(id: item.id) {
            image = await ImageLoader.shared.thumbnail(for: item, maxPixelSize: Self.pixelSize)
        }
    }
}
