import AppKit

/// In-memory cache for decoded images. NSCache handles memory pressure automatically.
final class ImageCache {
    private let cache = NSCache<NSString, NSImage>()

    func image(for item: PhotoItem, size: ImageSize) -> NSImage? {
        cache.object(forKey: cacheKey(for: item, size: size) as NSString)
    }

    func setImage(_ image: NSImage, for item: PhotoItem, size: ImageSize) {
        cache.setObject(image, forKey: cacheKey(for: item, size: size) as NSString)
    }

    private func cacheKey(for item: PhotoItem, size: ImageSize) -> String {
        switch size {
        case let .thumbnail(maxPixelSize): "\(item.sourceURL.path)@\(maxPixelSize)"
        case .full: "\(item.sourceURL.path)@full"
        }
    }
}
