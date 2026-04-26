import AppKit
import ImageIO

/// Loads thumbnail and full images from photo files, caching results in memory.
///
/// Each call checks the in-memory cache first, then decodes the image on the
/// cooperative thread pool via Task.detached so multiple images can load in
/// parallel without blocking the main actor. NSImage creation and cache writes
/// happen on the main actor after decoding completes.
@MainActor
final class ImageLoader {
    static let shared = ImageLoader()

    private let cache = NSCache<NSString, NSImage>()

    func fullImage(for item: PhotoItem) async -> NSImage? {
        let key = "\(item.sourceURL.path)@full" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let url = item.sourceURL
        let decoded = await Task.detached(priority: .userInitiated) {
            Self.decodeFullImage(from: url)
        }.value
        guard let cgImage = decoded else { return nil }

        let image = NSImage(cgImage: cgImage, size: .zero)
        cache.setObject(image, forKey: key)
        return image
    }

    func thumbnail(for item: PhotoItem, maxPixelSize: Int) async -> NSImage? {
        let key = "\(item.sourceURL.path)@\(maxPixelSize)" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let url = item.sourceURL
        let decoded = await Task.detached(priority: .userInitiated) {
            Self.decodeThumbnail(from: url, maxPixelSize: maxPixelSize)
        }.value
        guard let cgImage = decoded else { return nil }

        let image = NSImage(cgImage: cgImage, size: .zero)
        cache.setObject(image, forKey: key)
        return image
    }

    /// Extracts the embedded JPEG preview from a RAW file at full size. Using
    /// kCGImageSourceCreateThumbnailFromImageIfAbsent: false ensures CGImageSource
    /// returns the pre-existing embedded preview rather than decoding the RAW data.
    /// kCGImageSourceCreateThumbnailWithTransform applies the EXIF orientation tag
    /// so portrait shots display upright without any additional rotation.
    nonisolated static func decodeFullImage(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: false,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Decodes a thumbnail using CGImageSource. Marked nonisolated so it can run
    /// freely on background threads via Task.detached.
    nonisolated static func decodeThumbnail(from url: URL, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
