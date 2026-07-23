import AppKit
import SwiftUI

/// A fixed-size square that loads and displays a photo thumbnail, showing a
/// neutral placeholder while loading. Requests high-priority loading on
/// appear and deprioritises on disappear so that currently-visible cells are
/// always decoded first. Carries no selection or workflow chrome — cells
/// compose their own overlays on top.
struct ThumbnailImage: View {
    let item: PhotoItem

    // Request at 2x the display size for Retina screens.
    static let displaySize: Int = 260
    static let pixelSize: Int = displaySize * 2
    static let imageSize: ImageSize = .thumbnail(maxPixelSize: pixelSize)

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(3)
            } else {
                Color(nsColor: .quaternaryLabelColor)
            }
        }
        .frame(width: CGFloat(Self.displaySize), height: CGFloat(Self.displaySize))
        .onAppear {
            if let cached = ImagePipeline.shared.cachedImage(for: item, size: Self.imageSize) {
                image = cached
            } else {
                ImagePipeline.shared.requestImage(for: item, size: Self.imageSize)
            }
        }
        .onDisappear {
            ImagePipeline.shared.deprioritizeImage(for: item, size: Self.imageSize)
        }
        .onReceive(NotificationCenter.default.publisher(for: ImagePipeline.imageLoadedNotification)) { notification in
            guard (notification.userInfo?[ImagePipeline.imageLoadedItemIDKey] as? UUID) == item.id else { return }
            image = ImagePipeline.shared.cachedImage(for: item, size: Self.imageSize)
        }
    }
}
