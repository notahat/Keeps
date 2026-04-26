import SwiftUI
import AppKit

/// A fixed-size square cell that loads and displays a photo thumbnail.
/// Shows a neutral placeholder while loading. Uses .task(id:) so the load
/// is automatically cancelled if the cell scrolls out of view.
struct ThumbnailView: View {
    let item: PhotoItem
    var isSelected: Bool = false

    @Environment(\.controlActiveState) private var controlActiveState

    // Request at 2x the display size for Retina screens.
    private static let displaySize: Int = 260
    private static let pixelSize: Int = displaySize * 2

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(3)
                    .overlay {
                        if isSelected && controlActiveState == .key {
                            Rectangle().stroke(Color.accentColor, lineWidth: 3)
                        }
                    }
            } else {
                Color(nsColor: .quaternaryLabelColor)
            }
        }
        .frame(width: CGFloat(Self.displaySize), height: CGFloat(Self.displaySize))
        .task(id: item.id) {
            image = await ImageLoader.shared.thumbnail(for: item, maxPixelSize: Self.pixelSize)
        }
    }
}
