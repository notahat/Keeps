import AppKit
import SwiftUI

/// Shows one photo's thumbnail in a fixed-size frame, square unless given a
/// size, with a placeholder until the thumbnail loads.
///
/// When the view appears, it asks the image pipeline for the thumbnail at
/// the priority for images on screen. When it disappears, it drops the
/// request to background priority, so thumbnails on screen load before
/// ones that have scrolled away. It can draw a border round the image,
/// because only this view knows the image's real shape.
///
/// It draws no selection highlight, badge, or other decoration; the screens
/// add their own on top.
struct ThumbnailImage: View {
    let item: PhotoItem

    /// A border drawn around the image itself, following its shape rather
    /// than the frame's. Zero for none.
    var borderWidth: CGFloat = 0
    var borderColor: Color = .white

    /// When true, the image is queued at background priority even while on
    /// screen, as if it were off-screen — for images that are mostly hidden,
    /// such as the lower layers of a pile.
    var loadsInBackground = false

    /// What to show while the image loads.
    var placeholder: Placeholder = .square

    /// The space the image is fitted into. The same thumbnail is loaded
    /// whatever this is, so a larger frame scales it up.
    var frameSize = CGSize(width: CGFloat(Self.displaySize), height: CGFloat(Self.displaySize))

    /// Receives the image's width-to-height ratio once it has loaded.
    var onAspectRatioKnown: ((CGFloat) -> Void)?

    /// A stand-in for the image while it loads.
    enum Placeholder {
        /// A neutral square filling the frame.
        case square

        /// A card of a guessed width-to-height ratio, drawn in the border
        /// colour with a grey patch where the image will go, like paper
        /// awaiting its print.
        case paper(aspectRatio: CGFloat)

        /// Nothing, for images that should simply appear once ready.
        case none
    }

    /// The width and height, in points, of the frame thumbnails are usually
    /// shown in.
    static let displaySize: Int = 260

    /// The longest side of a thumbnail, in pixels: twice the display size,
    /// so thumbnails are sharp on Retina screens.
    static let pixelSize: Int = displaySize * 2

    /// The size thumbnails are read and cached at.
    static let imageSize: ImageSize = .thumbnail(maxPixelSize: pixelSize)

    /// The shape of most camera sensors, width over height, for laying out
    /// photos before their thumbnails have loaded, or piles whose photos
    /// may differ.
    static let typicalAspectRatio: CGFloat = 1.5

    /// How far in from the frame's edges the image is drawn. Views that zoom
    /// out of a thumbnail inset their image by the same amount, so it lines
    /// up.
    static let imageInset: CGFloat = 3

    /// The most common shape among the photos' cached thumbnails, width over
    /// height, or the typical shape when none are cached. Tiles laid out
    /// before the thumbnails load take this shape, so most photos fill
    /// their tiles.
    static func commonAspectRatio(of photos: some Sequence<PhotoItem>) -> CGFloat {
        let ratios = photos.compactMap { photo -> CGFloat? in
            guard let size = ImagePipeline.shared.cachedImage(for: photo, size: imageSize)?.size,
                  size.height > 0
            else { return nil }
            return size.width / size.height
        }
        return TileLayout.commonAspectRatio(of: ratios) ?? typicalAspectRatio
    }

    /// The thumbnail, which redraws this view when it loads. It's nil until
    /// the view first appears.
    @State private var thumbnail: WatchedImage?

    var body: some View {
        ThumbnailFrame(
            image: thumbnail?.image,
            borderWidth: borderWidth,
            borderColor: borderColor,
            placeholder: placeholder,
            frameSize: frameSize
        )
        .onAppear {
            loadThumbnail()
        }
        .onDisappear {
            ImagePipeline.shared.deprioritizeImage(for: item, size: Self.imageSize)
        }
        .onChange(of: thumbnail?.image) { _, loaded in
            reportAspectRatio(of: loaded)
        }
    }

    /// Starts watching the thumbnail, and asks for it to be read if it isn't
    /// cached.
    private func loadThumbnail() {
        let watched = ImagePipeline.shared.watchedImage(for: item, size: Self.imageSize)
        thumbnail = watched
        guard watched.image == nil else { return }
        if loadsInBackground {
            ImagePipeline.shared.prefetchImage(for: item, size: Self.imageSize)
        } else {
            ImagePipeline.shared.requestImage(for: item, size: Self.imageSize)
        }
    }

    /// Passes a loaded thumbnail's width-to-height ratio to
    /// onAspectRatioKnown.
    private func reportAspectRatio(of loaded: NSImage?) {
        guard let loaded, loaded.size.height > 0 else { return }
        onAspectRatioKnown?(loaded.size.width / loaded.size.height)
    }
}

/// Draws a thumbnail, or its placeholder while there's no image yet, with no
/// tie to the image pipeline, so it can be previewed. Loading is left to
/// ThumbnailImage.
private struct ThumbnailFrame: View {
    let image: NSImage?
    let borderWidth: CGFloat
    let borderColor: Color
    let placeholder: ThumbnailImage.Placeholder
    let frameSize: CGSize

    var body: some View {
        Group {
            if let image {
                // The border's padding shrinks what the image is offered, so
                // the image and its border together still fit the frame.
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(borderWidth)
                    .background(borderFill)
                    .padding(ThumbnailImage.imageInset)
            } else {
                placeholderView
            }
        }
        .frame(width: frameSize.width, height: frameSize.height)
    }

    /// The stand-in drawn while loading (see ThumbnailImage.Placeholder).
    @ViewBuilder private var placeholderView: some View {
        switch placeholder {
        case .square:
            Color(nsColor: .quaternaryLabelColor)
        case let .paper(aspectRatio):
            BlankPrint(aspectRatio: aspectRatio, borderWidth: borderWidth, borderColor: borderColor)
        case .none:
            EmptyView()
        }
    }

    /// What fills the border around the image: the border colour, or
    /// nothing when there's no border.
    private var borderFill: Color {
        borderWidth > 0 ? borderColor : .clear
    }
}

/// The frame every preview uses, the size thumbnails are shown at.
private let previewFrameSize = CGSize(
    width: CGFloat(ThumbnailImage.displaySize),
    height: CGFloat(ThumbnailImage.displaySize)
)

#Preview("Landscape photo, no border") {
    ThumbnailFrame(
        image: NSImage(contentsOf: PreviewPhotos.landscape.sourceURL),
        borderWidth: 0, borderColor: .white,
        placeholder: .square, frameSize: previewFrameSize
    )
    .padding()
    .background(.black)
}

#Preview("Portrait photo, white border") {
    ThumbnailFrame(
        image: NSImage(contentsOf: PreviewPhotos.portrait.sourceURL),
        borderWidth: 6, borderColor: .white,
        placeholder: .square, frameSize: previewFrameSize
    )
    .padding()
    .background(.black)
}

#Preview("Loading, square placeholder") {
    ThumbnailFrame(
        image: nil, borderWidth: 0, borderColor: .white,
        placeholder: .square, frameSize: previewFrameSize
    )
    .padding()
    .background(.black)
}

#Preview("Loading, blank paper placeholder") {
    ThumbnailFrame(
        image: nil, borderWidth: 6, borderColor: .white,
        placeholder: .paper(aspectRatio: ThumbnailImage.typicalAspectRatio), frameSize: previewFrameSize
    )
    .padding()
    .background(.black)
}
