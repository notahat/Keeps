import AppKit
import SwiftUI

/// A fixed-size square that loads and displays a photo thumbnail, showing a
/// neutral placeholder while loading. Requests high-priority loading on
/// appear and deprioritises on disappear so that currently-visible cells are
/// always decoded first. Carries no selection or workflow chrome — cells
/// compose their own overlays on top. Offers an optional border because
/// only this view knows the image's real shape.
struct ThumbnailImage: View {
    let item: PhotoItem

    /// A border drawn around the image itself, following its shape rather
    /// than the square cell. Zero for none.
    var borderWidth: CGFloat = 0
    var borderColor: Color = .white

    // Request at 2x the display size for Retina screens.
    static let displaySize: Int = 260
    static let pixelSize: Int = displaySize * 2
    static let imageSize: ImageSize = .thumbnail(maxPixelSize: pixelSize)

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                // The border's padding shrinks what the image is offered, so
                // image plus border still fits the square.
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(borderWidth)
                    .background(borderColor.opacity(borderWidth > 0 ? 1 : 0))
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
