/// Identifies which size of decoded image is being requested or cached.
nonisolated enum ImageSize: Hashable {
    case thumbnail(maxPixelSize: Int)
    case full
}
