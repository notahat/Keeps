import AppKit
import ImageIO

/// Pure functions for reading images from files using CGImageSource. All
/// methods are safe to call from any thread.
enum ImageReader {
    /// Extracts the embedded JPEG preview from a RAW file at full size.
    /// Turning off kCGImageSourceCreateThumbnailFromImageIfAbsent makes
    /// CGImageSource return the embedded preview rather than decoding the RAW
    /// data. kCGImageSourceCreateThumbnailWithTransform applies the EXIF
    /// orientation, so portrait shots display upright with no extra rotation.
    nonisolated static func fullImage(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: false,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Reads a scaled-down thumbnail. For JPEGs, decodes from the full image
    /// data to avoid the tiny blurry EXIF thumbnail. For RAWs, uses the
    /// embedded full-resolution JPEG preview for speed.
    nonisolated static func thumbnail(from url: URL, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let jpegExtensions: Set = ["jpg", "jpeg"]
        let isJPEG = jpegExtensions.contains(url.pathExtension.lowercased())
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: isJPEG,
            kCGImageSourceCreateThumbnailFromImageIfAbsent: !isJPEG,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
