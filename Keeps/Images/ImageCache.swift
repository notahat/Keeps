import AppKit
import Synchronization

/// Holds decoded images in memory, by photo and size. NSCache evicts them
/// under memory pressure, so a miss means the image needs reading again.
/// It also keeps a tally of what it holds at each size, for the debug
/// overlay, since NSCache can't list its contents. It doesn't read or
/// schedule anything; that's ImagePipeline's job.
final class ImageCache {
    /// How many images of one size are cached, and roughly how much memory
    /// they take decoded.
    struct Contents: Equatable {
        let size: ImageSize
        let imageCount: Int
        let byteCount: Int
    }

    /// The images, keyed by cacheKey.
    private let cache = NSCache<NSString, NSImage>()

    /// What the cache holds at each size, kept alongside it since NSCache
    /// can't list its contents.
    private let tally = CacheTally()

    /// Make an empty cache.
    init() {
        cache.delegate = tally
    }

    /// Return the cached image of a photo at a size, or nil if there isn't
    /// one.
    func image(for photo: PhotoItem, size: ImageSize) -> NSImage? {
        cache.object(forKey: cacheKey(for: photo, size: size) as NSString)
    }

    /// Cache the image of a photo at a size, replacing any already there.
    func setImage(_ image: NSImage, for photo: PhotoItem, size: ImageSize) {
        let key = cacheKey(for: photo, size: size) as NSString
        // NSCache may not report a replaced image as evicted, so it's taken
        // out of the tally here. Otherwise it would be counted forever.
        if let replaced = cache.object(forKey: key) {
            tally.remove(replaced)
        }
        tally.add(image, size: size)
        cache.setObject(image, forKey: key)
    }

    /// Return what's cached at each size: scaled images from smallest to
    /// largest, then full-size images.
    func contents() -> [Contents] {
        tally.contents()
    }

    /// Return the key an image is cached under: the photo's file and the
    /// size.
    private func cacheKey(for photo: PhotoItem, size: ImageSize) -> String {
        switch size {
        case let .scaled(longestSideLength): "\(photo.sourceURL.path)@\(longestSideLength)"
        case .full: "\(photo.sourceURL.path)@full"
        }
    }
}

/// Keeps count of the images in an NSCache, as its delegate, so it hears
/// when one is evicted. NSCache can evict from any thread, so the counts
/// are behind a lock.
private final nonisolated class CacheTally: NSObject, NSCacheDelegate, Sendable {
    /// One cached image's size and memory.
    private struct Entry {
        let size: ImageSize
        let byteCount: Int
    }

    /// The cached images, by identity, since eviction gives only the image.
    private let entries = Mutex<[ObjectIdentifier: Entry]>([:])

    /// Count an image newly cached at a size.
    func add(_ image: NSImage, size: ImageSize) {
        let entry = Entry(size: size, byteCount: Self.byteCount(of: image))
        entries.withLock { $0[ObjectIdentifier(image)] = entry }
    }

    /// Stop counting an image that has left the cache, and return the size
    /// it was cached at, or nil if it wasn't being counted.
    @discardableResult
    func remove(_ image: NSImage) -> ImageSize? {
        entries.withLock { $0.removeValue(forKey: ObjectIdentifier(image))?.size }
    }

    /// Stop counting an image NSCache is evicting, and mark the eviction for
    /// Instruments.
    func cache(_: NSCache<AnyObject, AnyObject>, willEvictObject object: Any) {
        guard let image = object as? NSImage, let size = remove(image) else { return }
        ImageSignposts.markEviction(of: size)
    }

    /// Return the counts at each size, scaled images from smallest to
    /// largest, then full-size images.
    func contents() -> [ImageCache.Contents] {
        let grouped = entries.withLock { entries in
            Dictionary(grouping: entries.values, by: \.size)
        }
        return grouped
            .map { size, entries in
                ImageCache.Contents(size: size, imageCount: entries.count, byteCount: entries.sum(of: \.byteCount))
            }
            .sorted { $0.size.sortOrder < $1.size.sortOrder }
    }

    /// Return roughly how many bytes of memory an image takes decoded: four
    /// a pixel. Return zero if the image has no bitmap to measure.
    private static func byteCount(of image: NSImage) -> Int {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return 0 }
        return cgImage.width * cgImage.height * 4
    }
}

private nonisolated extension Array {
    /// Return the total of a number taken from each element.
    func sum(of value: (Element) -> Int) -> Int {
        reduce(0) { $0 + value($1) }
    }
}

private nonisolated extension ImageSize {
    /// Where the size sorts in a list: scaled images by size, then full.
    var sortOrder: Int {
        switch self {
        case let .scaled(longestSideLength): longestSideLength
        case .full: .max
        }
    }
}
