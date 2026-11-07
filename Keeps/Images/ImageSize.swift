/// Which of a photo's images is being asked for or cached: the thumbnail,
/// the medium image, or the full image.
///
/// The thumbnail and the medium image are fixed `.scaled` sizes rather than
/// sizes worked out from each frame, so the cache, which keys images by
/// size, shares one copy of each between every view that shows it, and
/// resizing a window doesn't start new reads. ImageSize also holds the rule
/// for which of the three a frame shows. It doesn't read images:
/// ImageReader turns a size into pixels for each kind of file.
///
/// The sizes come from what the decoders cost; Benchmarks/README.md has the
/// measurements.
nonisolated enum ImageSize: Hashable, CustomStringConvertible {
    /// An image scaled down so its longest side is no more than this length
    /// in pixels, such as a thumbnail or a medium image.
    case scaled(longestSideLength: Int)

    /// The image the full-size view and the largest tiles show: a RAW file's
    /// embedded preview as it is, or a JPEG file scaled down to a size
    /// ImageReader chooses.
    case full

    /// The longest side of a thumbnail, in pixels: twice the length of the
    /// standard frame (FramedPhoto.standardFrameLength), so thumbnails are
    /// sharp in it on Retina screens.
    static let thumbnailLongestSideLength = 520

    /// The longest side of a medium image, in pixels. 1932 px is a quarter of
    /// a Fuji X-T5 JPEG file's longest side, which the JPEG decoder reads more
    /// cheaply than any other size. Reading a RAW file at this size costs no
    /// more than at 2048 px. A frame larger than this shows the full image,
    /// which reads more cheaply than any size in between.
    static let mediumImageLongestSideLength = 1932

    /// The thumbnail, for cells, piles, and drag images, and to stand in
    /// while a larger image loads.
    static let thumbnail: ImageSize = .scaled(longestSideLength: thumbnailLongestSideLength)

    /// The medium image, for frames larger than a thumbnail but no longer
    /// than the medium image.
    static let mediumImage: ImageSize = .scaled(longestSideLength: mediumImageLongestSideLength)

    /// Choose the image to show in a frame whose longest side is this many
    /// pixels long: the smallest of the thumbnail, the medium image, and the
    /// full image that's at least that long.
    static func choose(forLongestSideLength length: Double) -> ImageSize {
        if length <= Double(thumbnailLongestSideLength) {
            thumbnail
        } else if length <= Double(mediumImageLongestSideLength) {
            mediumImage
        } else {
            .full
        }
    }

    /// The size's name, such as "520 px" or "full", for the debug overlay
    /// and signposts.
    var description: String {
        switch self {
        case let .scaled(longestSideLength): "\(longestSideLength) px"
        case .full: "full"
        }
    }
}
