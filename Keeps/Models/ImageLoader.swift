import AppKit

/// Schedules image decodes and caches results. Routes all decodes through a
/// bounded OperationQueue: user-visible requests at high priority, background
/// prefetch at low. Signals completion via NotificationCenter so that on-screen
/// views can update without suspending on async/await.
@MainActor
final class ImageLoader {
    static let shared = ImageLoader()

    /// Posted on the main thread when a thumbnail finishes decoding. The userInfo
    /// dictionary carries the item's UUID under thumbnailItemIDKey.
    static let thumbnailLoadedNotification = Notification.Name("com.notahat.Keeps.thumbnailLoaded")
    static let thumbnailItemIDKey = "itemID"

    /// Posted on the main thread when a full image finishes decoding. The userInfo
    /// dictionary carries the item's UUID under fullImageItemIDKey.
    static let fullImageLoadedNotification = Notification.Name("com.notahat.Keeps.fullImageLoaded")
    static let fullImageItemIDKey = "itemID"

    private let cache = ImageCache()

    /// Worker pool. maxConcurrentOperationCount controls decode parallelism —
    /// tune this to balance throughput against memory and responsiveness.
    private let decodeQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.notahat.Keeps.ImageLoader"
        queue.maxConcurrentOperationCount = 16
        return queue
    }()

    /// All in-flight thumbnail operations keyed by item identity + size. Includes
    /// both user-visible (high priority) and background prefetch (low priority) ops.
    private var thumbnailOps: [String: Operation] = [:]

    /// All in-flight full-image operations keyed by item identity.
    private var fullImageOps: [String: Operation] = [:]

    // MARK: - Full images

    /// Returns the cached full image immediately, or nil if not yet loaded.
    func cachedFullImage(for item: PhotoItem) -> NSImage? {
        cache.fullImage(for: item)
    }

    /// Starts loading a full image at high priority, or promotes an existing
    /// operation. Called when a view needs the full image as soon as possible.
    func requestFullImage(for item: PhotoItem) {
        let key = fullImageKey(for: item)
        guard cache.fullImage(for: item) == nil else { return }
        if let op = fullImageOps[key] {
            op.queuePriority = .veryHigh
            return
        }
        let url = item.sourceURL
        fullImageOps[key] = makeOp(
            key: key,
            priority: .veryHigh,
            decode: { ImageDecoder.fullImage(from: url) },
            store: { ImageLoader.shared.cache.setFullImage($0, for: item) },
            itemID: item.id,
            onComplete: { ImageLoader.shared.completeFullImageLoad(key: key, itemID: item.id) }
        )
    }

    /// Starts loading a full image at low priority if not already in flight.
    /// Used to warm the cache for nearby images in SingleImageView.
    func prefetchFullImage(for item: PhotoItem) {
        let key = fullImageKey(for: item)
        guard cache.fullImage(for: item) == nil, fullImageOps[key] == nil else { return }
        let url = item.sourceURL
        fullImageOps[key] = makeOp(
            key: key,
            priority: .high,
            decode: { ImageDecoder.fullImage(from: url) },
            store: { ImageLoader.shared.cache.setFullImage($0, for: item) },
            itemID: item.id,
            onComplete: { ImageLoader.shared.completeFullImageLoad(key: key, itemID: item.id) }
        )
    }

    /// Drops a full image back to background priority. Called when the view
    /// showing it leaves the screen.
    func deprioritizeFullImage(for item: PhotoItem) {
        fullImageOps[fullImageKey(for: item)]?.queuePriority = .high
    }

    private func completeFullImageLoad(key: String, itemID: UUID) {
        fullImageOps.removeValue(forKey: key)
        NotificationCenter.default.post(
            name: ImageLoader.fullImageLoadedNotification,
            object: nil,
            userInfo: [ImageLoader.fullImageItemIDKey: itemID]
        )
    }

    private func fullImageKey(for item: PhotoItem) -> String {
        "\(item.id)@full"
    }

    // MARK: - Thumbnails

    /// Returns the cached thumbnail immediately, or nil if not yet loaded.
    func cachedThumbnail(for item: PhotoItem, maxPixelSize: Int) -> NSImage? {
        cache.thumbnail(for: item, maxPixelSize: maxPixelSize)
    }

    /// Starts loading a thumbnail at high priority, or promotes an existing
    /// prefetch. Called when a grid cell enters the visible viewport.
    func requestThumbnail(for item: PhotoItem, maxPixelSize: Int) {
        let key = thumbnailKey(for: item, maxPixelSize: maxPixelSize)
        guard cache.thumbnail(for: item, maxPixelSize: maxPixelSize) == nil else { return }
        if let op = thumbnailOps[key] {
            op.queuePriority = .low
            return
        }
        let url = item.sourceURL
        thumbnailOps[key] = makeOp(
            key: key,
            priority: .low,
            decode: { ImageDecoder.thumbnail(from: url, maxPixelSize: maxPixelSize) },
            store: { ImageLoader.shared.cache.setThumbnail($0, for: item, maxPixelSize: maxPixelSize) },
            itemID: item.id,
            onComplete: { ImageLoader.shared.completeThumbnailLoad(key: key, itemID: item.id) }
        )
    }

    /// Drops a thumbnail back to background priority. Called when a grid cell
    /// leaves the viewport. Has no effect if the operation has already started.
    func deprioritizeThumbnail(for item: PhotoItem, maxPixelSize: Int) {
        thumbnailOps[thumbnailKey(for: item, maxPixelSize: maxPixelSize)]?.queuePriority = .veryLow
    }

    /// Queues background loads for all items. Cancels any previous prefetch ops
    /// that have not been promoted by a user request.
    func prefetchThumbnails(for items: [PhotoItem], maxPixelSize: Int) {
        cancelIdlePrefetch()
        for item in items {
            let key = thumbnailKey(for: item, maxPixelSize: maxPixelSize)
            guard cache.thumbnail(for: item, maxPixelSize: maxPixelSize) == nil,
                  thumbnailOps[key] == nil else { continue }
            let url = item.sourceURL
            thumbnailOps[key] = makeOp(
                key: key,
                priority: .veryLow,
                decode: { ImageDecoder.thumbnail(from: url, maxPixelSize: maxPixelSize) },
                store: { ImageLoader.shared.cache.setThumbnail($0, for: item, maxPixelSize: maxPixelSize) },
                itemID: item.id,
                onComplete: { ImageLoader.shared.completeThumbnailLoad(key: key, itemID: item.id) }
            )
        }
    }

    /// Cancels ops that are still at low priority and have not been promoted to
    /// a user-visible request.
    private func cancelIdlePrefetch() {
        thumbnailOps = thumbnailOps.filter { _, op in
            if op.queuePriority == .veryLow {
                op.cancel()
                return false
            }
            return true
        }
    }

    private func completeThumbnailLoad(key: String, itemID: UUID) {
        thumbnailOps.removeValue(forKey: key)
        NotificationCenter.default.post(
            name: ImageLoader.thumbnailLoadedNotification,
            object: nil,
            userInfo: [ImageLoader.thumbnailItemIDKey: itemID]
        )
    }

    private func thumbnailKey(for item: PhotoItem, maxPixelSize: Int) -> String {
        "\(item.id)@\(maxPixelSize)"
    }

    // MARK: - Shared

    private func makeOp(
        key _: String,
        priority: Operation.QueuePriority,
        decode: @escaping @Sendable () -> CGImage?,
        store: @escaping @MainActor (NSImage) -> Void,
        itemID _: UUID,
        onComplete: @escaping @MainActor () -> Void
    ) -> Operation {
        let op = BlockOperation {
            let cgImage = decode()
            Task { @MainActor in
                let image = cgImage.map { NSImage(cgImage: $0, size: .zero) }
                if let image { store(image) }
                onComplete()
            }
        }
        op.queuePriority = priority
        decodeQueue.addOperation(op)
        return op
    }
}
