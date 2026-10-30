import AppKit
import SwiftUI

/// A fixed-size square that loads and displays a photo thumbnail, showing a
/// neutral placeholder while loading. By default requests visible-priority
/// loading on appear and deprioritises on disappear so that currently-visible
/// cells are always decoded first. Carries no selection or grouping chrome —
/// cells compose their own overlays on top. Offers an optional border because
/// only this view knows the image's real shape.
struct ThumbnailImage: View {
    let item: PhotoItem

    /// A border drawn around the image itself, following its shape rather
    /// than the square cell. Zero for none.
    var borderWidth: CGFloat = 0
    var borderColor: Color = .white

    /// When true, the image is queued at background priority even while on
    /// screen, as if it were off-screen — for images that are mostly hidden,
    /// such as the lower layers of a pile.
    var loadsInBackground = false

    /// What to show while the image loads.
    var placeholder: Placeholder = .square

    /// Receives the image's width-to-height ratio once it has loaded.
    var onAspectRatioKnown: ((CGFloat) -> Void)?

    /// A stand-in for the image while it loads.
    enum Placeholder {
        /// A neutral square filling the cell.
        case square

        /// A card of a guessed width-to-height ratio, drawn in the border
        /// colour with a grey patch where the image will go, like paper
        /// awaiting its print.
        case paper(aspectRatio: CGFloat)

        /// Nothing, for images that should simply appear once ready.
        case none
    }

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
                    .background(borderFill)
                    .padding(3)
            } else {
                placeholderView
            }
        }
        .frame(width: CGFloat(Self.displaySize), height: CGFloat(Self.displaySize))
        .onAppear {
            if let cached = ImagePipeline.shared.cachedImage(for: item, size: Self.imageSize) {
                show(cached)
            } else if loadsInBackground {
                ImagePipeline.shared.prefetchImage(for: item, size: Self.imageSize)
            } else {
                ImagePipeline.shared.requestImage(for: item, size: Self.imageSize)
            }
        }
        .onDisappear {
            ImagePipeline.shared.deprioritizeImage(for: item, size: Self.imageSize)
        }
        .onReceive(NotificationCenter.default.publisher(for: ImagePipeline.imageLoadedNotification)) { notification in
            guard (notification.userInfo?[ImagePipeline.imageLoadedItemIDKey] as? UUID) == item.id,
                  let loaded = ImagePipeline.shared.cachedImage(for: item, size: Self.imageSize)
            else { return }
            show(loaded)
        }
    }

    /// The stand-in drawn while loading (see Placeholder).
    @ViewBuilder private var placeholderView: some View {
        switch placeholder {
        case .square:
            Color(nsColor: .quaternaryLabelColor)
        case let .paper(aspectRatio):
            Color(white: 0.5)
                .padding(borderWidth)
                .background(borderFill)
                .aspectRatio(aspectRatio, contentMode: .fit)
                .padding(3)
        case .none:
            EmptyView()
        }
    }

    /// What fills the border around the image: the border colour, or
    /// nothing when there's no border.
    private var borderFill: Color {
        borderWidth > 0 ? borderColor : .clear
    }

    /// Displays a loaded image and reports its shape.
    private func show(_ loaded: NSImage) {
        image = loaded
        guard loaded.size.height > 0 else { return }
        onAspectRatioKnown?(loaded.size.width / loaded.size.height)
    }
}
