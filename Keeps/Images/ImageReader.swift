import Foundation
import ImageIO

/// Reads photos from files as images scaled to the size the app wants
/// (`ImageSize`). Each format has its own reader, `RAWImageReader` or
/// `JPEGImageReader`, and this hands each file to the right one. It holds no
/// state, so all its methods are safe to call from any thread.
///
/// Every read applies the photo's EXIF orientation, so portrait shots come
/// out upright.
enum ImageReader {
    /// Read a photo's image at a size, returning nil if the file can't be
    /// read.
    nonisolated static func image(from url: URL, size: ImageSize) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        if isJPEG(url) {
            return JPEGImageReader.image(from: source, size: size)
        } else {
            return RAWImageReader.image(from: source, size: size)
        }
    }

    /// Return true if a file is a JPEG, going by its extension.
    private nonisolated static func isJPEG(_ url: URL) -> Bool {
        ["jpg", "jpeg"].contains(url.pathExtension.lowercased())
    }
}
