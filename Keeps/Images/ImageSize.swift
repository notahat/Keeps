/// Identifies which size of decoded image is being requested or cached.
nonisolated enum ImageSize: Hashable, CustomStringConvertible {
    /// An image scaled down so its longest side is no more than this length
    /// in pixels, for the sort screen's cells and the tiles.
    case thumbnail(longestSideLength: Int)

    /// The image the full-size view shows: a RAW file's embedded preview as
    /// it is, or a JPEG file scaled down to a size ImageReader chooses.
    case full

    /// The longest side of the tile image, in pixels. 1932 px is a quarter
    /// of a Fuji X-T5 JPEG file's longest side, which the JPEG decoder reads
    /// more cheaply than any other size. Reading a RAW file at this size
    /// costs no more than at 2048 px. A frame larger than this shows the
    /// full image, which reads more cheaply than any size in between.
    static let tileLongestSideLength = 1932

    /// The image a tile shows when it's larger than a thumbnail but no
    /// longer than the tile image's longest side.
    static let tile: ImageSize = .thumbnail(longestSideLength: tileLongestSideLength)

    /// The size's name, such as "520 px" or "full", for the debug overlay
    /// and signposts.
    var description: String {
        switch self {
        case let .thumbnail(longestSideLength): "\(longestSideLength) px"
        case .full: "full"
        }
    }
}
