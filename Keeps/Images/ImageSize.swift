/// Identifies which size of decoded image is being requested or cached.
nonisolated enum ImageSize: Hashable, CustomStringConvertible {
    /// An image scaled down so its longest side is no more than this length
    /// in pixels, such as a thumbnail or a medium image.
    case scaled(longestSideLength: Int)

    /// The image the full-size view shows: a RAW file's embedded preview as
    /// it is, or a JPEG file scaled down to a size ImageReader chooses.
    case full

    /// The size's name, such as "520 px" or "full", for the debug overlay
    /// and signposts.
    var description: String {
        switch self {
        case let .scaled(longestSideLength): "\(longestSideLength) px"
        case .full: "full"
        }
    }
}
