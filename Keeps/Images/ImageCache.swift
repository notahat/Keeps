import AppKit

/// Holds decoded images in memory, by photo and size. NSCache evicts them
/// under memory pressure, so a miss means the image needs reading again.
/// It doesn't read or schedule anything; that's ImagePipeline's job.
final class ImageCache {
    private let cache = NSCache<NSString, NSImage>()

    /// The cached image of a photo at a size, or nil if there isn't one.
    func image(for item: PhotoItem, size: ImageSize) -> NSImage? {
        cache.object(forKey: cacheKey(for: item, size: size) as NSString)
    }

    /// Caches the image of a photo at a size, replacing any already there.
    func setImage(_ image: NSImage, for item: PhotoItem, size: ImageSize) {
        cache.setObject(image, forKey: cacheKey(for: item, size: size) as NSString)
    }

    /// The key an image is cached under: the photo's file and the size.
    private func cacheKey(for item: PhotoItem, size: ImageSize) -> String {
        switch size {
        case let .thumbnail(maxPixelSize): "\(item.sourceURL.path)@\(maxPixelSize)"
        case .full: "\(item.sourceURL.path)@full"
        }
    }
}
