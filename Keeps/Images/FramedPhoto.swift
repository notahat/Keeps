import AppKit
import SwiftUI

/// Shows one photo in a fixed-size frame, square unless given a size, with
/// a placeholder until its thumbnail loads. Cells, tiles, and piles all
/// show their photos with it.
///
/// It chooses which image to show by the frame's size in pixels: the
/// thumbnail, the medium image, or the full image. It always loads the
/// thumbnail, which stands in until a larger image arrives.
///
/// When the view appears, it asks the image pipeline for its images at the
/// priority for images on screen. When it disappears, it drops the
/// requests to background priority, so images on screen load before ones
/// that have scrolled away. It can draw a border round the image, because
/// only this view knows the image's real shape.
///
/// It draws no selection highlight, badge, or other decoration; the screens
/// add their own on top.
struct FramedPhoto: View {
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

    /// The space the image is fitted into. A frame larger than a thumbnail
    /// loads a larger image too.
    var frameSize = CGSize(width: CGFloat(Self.standardFrameLength), height: CGFloat(Self.standardFrameLength))

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

    /// The width and height, in points, of the usual frame: a cell on the
    /// sort and done screens.
    static let standardFrameLength: Int = 260

    /// The longest side of a thumbnail, in pixels: twice the standard
    /// frame's length, so thumbnails are sharp in it on Retina screens.
    static let thumbnailLongestSideLength: Int = standardFrameLength * 2

    /// The size thumbnails are read and cached at.
    static let thumbnailSize: ImageSize = .scaled(longestSideLength: thumbnailLongestSideLength)

    /// The longest side of the medium image, in pixels. 1932 px is a
    /// quarter of a Fuji X-T5 JPEG file's longest side, which the JPEG
    /// decoder reads more cheaply than any other size. Reading a RAW file
    /// at this size costs no more than at 2048 px. A frame larger than this
    /// shows the full image, which reads more cheaply than any size in
    /// between.
    static let mediumImageLongestSideLength: Int = 1932

    /// The size medium images are read and cached at, for frames larger
    /// than a thumbnail but no longer than the medium image.
    static let mediumImageSize: ImageSize = .scaled(longestSideLength: mediumImageLongestSideLength)

    /// Choose the image to show in a frame whose longest side is this many
    /// pixels long: the smallest of the thumbnail, the medium image, and the
    /// full image that's at least that long.
    static func chooseImageSize(forLongestSideLength length: CGFloat) -> ImageSize {
        if length <= CGFloat(thumbnailLongestSideLength) {
            thumbnailSize
        } else if length <= CGFloat(mediumImageLongestSideLength) {
            mediumImageSize
        } else {
            .full
        }
    }

    /// The shape of most camera sensors, width over height, for laying out
    /// photos before their thumbnails have loaded, or piles whose photos
    /// may differ.
    static let typicalAspectRatio: CGFloat = 1.5

    /// How far in from the frame's edges the image is drawn. Views that zoom
    /// out of a framed photo inset their image by the same amount, so it
    /// lines up.
    static let imageInset: CGFloat = 3

    /// The most common shape among the photos' cached thumbnails, width over
    /// height, or the typical shape when none are cached. Tiles laid out
    /// before the thumbnails load take this shape, so most photos fill
    /// their tiles.
    static func commonAspectRatio(of photos: some Sequence<PhotoItem>) -> CGFloat {
        let ratios = photos.compactMap { photo -> CGFloat? in
            guard let size = ImagePipeline.shared.cachedImage(for: photo, size: thumbnailSize)?.size,
                  size.height > 0
            else { return nil }
            return size.width / size.height
        }
        return TileLayout.commonAspectRatio(of: ratios) ?? typicalAspectRatio
    }

    /// How many pixels the screen has to a point.
    @Environment(\.displayScale) private var displayScale

    /// The thumbnail, which redraws this view when it loads. It's nil until
    /// the view first appears.
    @State private var thumbnail: WatchedImage?

    /// The larger image the frame calls for, which redraws this view when it
    /// loads. It's nil when the frame is no larger than a thumbnail.
    @State private var largerImage: WatchedImage?

    /// The size of the larger image the frame calls for, or nil when the
    /// frame is no larger than a thumbnail.
    private var largerImageSize: ImageSize? {
        let longestSideLength = max(frameSize.width, frameSize.height) * displayScale
        let size = Self.chooseImageSize(forLongestSideLength: longestSideLength)
        return size == Self.thumbnailSize ? nil : size
    }

    var body: some View {
        FramedPhotoContent(
            image: largerImage?.image ?? thumbnail?.image,
            borderWidth: borderWidth,
            borderColor: borderColor,
            placeholder: placeholder,
            frameSize: frameSize
        )
        .onAppear {
            // The thumbnail is asked for first, so it's read first and can
            // stand in while the larger image loads.
            thumbnail = loadImage(size: Self.thumbnailSize)
            largerImage = largerImageSize.map { loadImage(size: $0) }
        }
        .onDisappear {
            ImagePipeline.shared.deprioritizeImage(for: item, size: Self.thumbnailSize)
            if let largerImageSize {
                ImagePipeline.shared.deprioritizeImage(for: item, size: largerImageSize)
            }
        }
        .onChange(of: largerImageSize) { oldSize, newSize in
            if let oldSize {
                ImagePipeline.shared.deprioritizeImage(for: item, size: oldSize)
            }
            largerImage = newSize.map { loadImage(size: $0) }
        }
        .onChange(of: thumbnail?.image) { _, loaded in
            reportAspectRatio(of: loaded)
        }
    }

    /// Start watching the photo's image at a size, ask for it to be read if
    /// it isn't cached, and return the watched image.
    private func loadImage(size: ImageSize) -> WatchedImage {
        let watched = ImagePipeline.shared.watchedImage(for: item, size: size)
        guard watched.image == nil else { return watched }
        if loadsInBackground {
            ImagePipeline.shared.prefetchImage(for: item, size: size)
        } else {
            ImagePipeline.shared.requestImage(for: item, size: size)
        }
        return watched
    }

    /// Passes a loaded thumbnail's width-to-height ratio to
    /// onAspectRatioKnown.
    private func reportAspectRatio(of loaded: NSImage?) {
        guard let loaded, loaded.size.height > 0 else { return }
        onAspectRatioKnown?(loaded.size.width / loaded.size.height)
    }
}

/// Draws a framed photo's image, or its placeholder while there's no image
/// yet, with no tie to the image pipeline, so it can be previewed. Loading
/// is left to FramedPhoto.
private struct FramedPhotoContent: View {
    let image: NSImage?
    let borderWidth: CGFloat
    let borderColor: Color
    let placeholder: FramedPhoto.Placeholder
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
                    .padding(FramedPhoto.imageInset)
            } else {
                placeholderView
            }
        }
        .frame(width: frameSize.width, height: frameSize.height)
    }

    /// The stand-in drawn while loading (see FramedPhoto.Placeholder).
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

/// The frame every preview uses, the standard frame.
private let previewFrameSize = CGSize(
    width: CGFloat(FramedPhoto.standardFrameLength),
    height: CGFloat(FramedPhoto.standardFrameLength)
)

#Preview("Landscape photo, no border") {
    FramedPhotoContent(
        image: NSImage(contentsOf: PreviewPhotos.landscape.sourceURL),
        borderWidth: 0, borderColor: .white,
        placeholder: .square, frameSize: previewFrameSize
    )
    .padding()
    .background(.black)
}

#Preview("Portrait photo, white border") {
    FramedPhotoContent(
        image: NSImage(contentsOf: PreviewPhotos.portrait.sourceURL),
        borderWidth: 6, borderColor: .white,
        placeholder: .square, frameSize: previewFrameSize
    )
    .padding()
    .background(.black)
}

#Preview("Loading, square placeholder") {
    FramedPhotoContent(
        image: nil, borderWidth: 0, borderColor: .white,
        placeholder: .square, frameSize: previewFrameSize
    )
    .padding()
    .background(.black)
}

#Preview("Loading, blank paper placeholder") {
    FramedPhotoContent(
        image: nil, borderWidth: 6, borderColor: .white,
        placeholder: .paper(aspectRatio: FramedPhoto.typicalAspectRatio), frameSize: previewFrameSize
    )
    .padding()
    .background(.black)
}
