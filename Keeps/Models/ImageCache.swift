import AppKit

/// In-memory cache for decoded images. NSCache handles memory pressure automatically.
final class ImageCache {
    private let cache = NSCache<NSString, NSImage>()

    func thumbnail(for item: PhotoItem, maxPixelSize: Int) -> NSImage? {
        cache.object(forKey: thumbnailKey(for: item, maxPixelSize: maxPixelSize) as NSString)
    }

    func setThumbnail(_ image: NSImage, for item: PhotoItem, maxPixelSize: Int) {
        cache.setObject(image, forKey: thumbnailKey(for: item, maxPixelSize: maxPixelSize) as NSString)
    }

    func fullImage(for item: PhotoItem) -> NSImage? {
        cache.object(forKey: fullImageKey(for: item) as NSString)
    }

    func setFullImage(_ image: NSImage, for item: PhotoItem) {
        cache.setObject(image, forKey: fullImageKey(for: item) as NSString)
    }

    private func thumbnailKey(for item: PhotoItem, maxPixelSize: Int) -> String {
        "\(item.sourceURL.path)@\(maxPixelSize)"
    }

    private func fullImageKey(for item: PhotoItem) -> String {
        "\(item.sourceURL.path)@full"
    }
}
