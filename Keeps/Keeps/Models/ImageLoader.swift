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

    private var cache: [String: NSImage] = [:]

    func thumbnail(for item: PhotoItem, maxPixelSize: Int) async -> NSImage? {
        let key = cacheKey(url: item.sourceURL, size: maxPixelSize)
        if let cached = cache[key] { return cached }

        let url = item.sourceURL
        let decoded = await Task.detached(priority: .userInitiated) {
            Self.decodeThumbnail(from: url, maxPixelSize: maxPixelSize)
        }.value
        guard let cgImage = decoded else { return nil }

        let image = NSImage(cgImage: cgImage, size: .zero)
        cache[key] = image
        return image
    }

    private func cacheKey(url: URL, size: Int) -> String {
        "\(url.path)@\(size)"
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
