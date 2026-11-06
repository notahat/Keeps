/// Identifies which size of decoded image is being requested or cached.
nonisolated enum ImageSize: Hashable, CustomStringConvertible {
    /// An image scaled down to fit a square of this many pixels, for the
    /// sort screen's cells and the tiles.
    case thumbnail(maxPixelSize: Int)

    /// The image the full-size view shows: a RAW's embedded preview as it
    /// is, or a JPEG scaled down to no more than fullImageMaxPixelSize, at
    /// whatever size ImageReader can read most cheaply.
    case full

    /// The most pixels a JPEG's full image's longest side may have: the
    /// size of the JPEG preview a Fuji X-T5 embeds in its RAW files, which
    /// looks sharp enough even on a large external screen. Reading JPEGs in
    /// full instead, at 40 MP, makes Core Animation pause the main thread
    /// each time one first shows, for longer the more pixels it has.
    static let fullImageMaxPixelSize = 4416

    /// The size's name, such as "520 px" or "full", for the debug overlay
    /// and signposts.
    var description: String {
        switch self {
        case let .thumbnail(maxPixelSize): "\(maxPixelSize) px"
        case .full: "full"
        }
    }
}
