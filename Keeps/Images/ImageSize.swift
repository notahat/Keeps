/// Identifies which size of decoded image is being requested or cached.
nonisolated enum ImageSize: Hashable, CustomStringConvertible {
    case thumbnail(maxPixelSize: Int)
    case full

    /// The size's name, such as "520 px" or "full", for the debug overlay
    /// and signposts.
    var description: String {
        switch self {
        case let .thumbnail(maxPixelSize): "\(maxPixelSize) px"
        case .full: "full"
        }
    }
}
