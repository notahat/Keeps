/// Identifies which size of decoded image is being requested or cached.
enum ImageSize: Equatable {
    case thumbnail(maxPixelSize: Int)
    case full
}
