import AppKit
import Observation

/// Schedules image decodes and caches results. Routes all decodes through a
/// bounded OperationQueue: user-visible requests at high priority, background
/// prefetch at low. Signals completion via NotificationCenter so that on-screen
/// views can update without suspending on async/await.
@Observable
@MainActor
final class ImageLoader {
    static let shared = ImageLoader()

    /// Posted on the main thread when any image finishes decoding. The userInfo
    /// dictionary carries the item's UUID under imageLoadedItemIDKey.
    static let imageLoadedNotification = Notification.Name("com.notahat.Keeps.imageLoaded")
    static let imageLoadedItemIDKey = "itemID"

    private let cache = ImageCache()

    // Priority levels used across the decode queue. Higher tiers pre-empt lower
    // ones, so the user always sees the image they're looking at decode first.
    private static let currentImagePriority: Operation.QueuePriority = .veryHigh
    private static let nearbyImagePriority: Operation.QueuePriority = .high
    private static let visibleThumbnailPriority: Operation.QueuePriority = .low
    private static let backgroundPrefetchPriority: Operation.QueuePriority = .veryLow

    /// Worker pool. maxConcurrentOperationCount controls decode parallelism —
    /// tune this to balance throughput against memory and responsiveness.
    private let decodeQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.notahat.Keeps.ImageLoader"
        queue.maxConcurrentOperationCount = 16
        return queue
    }()

    /// All in-flight decode operations keyed by item identity + size. Includes
    /// both user-visible (high priority) and background prefetch (low priority) ops.
    private var imageOps: [String: Operation] = [:]

    /// The total number of decode operations currently queued or running.
    var queueCount: Int {
        imageOps.count
    }

    // MARK: - Public interface

    /// Returns the cached image immediately, or nil if not yet loaded.
    func cachedImage(for item: PhotoItem, size: ImageSize) -> NSImage? {
        cache.image(for: item, size: size)
    }

    /// Starts loading an image at high priority, or promotes an existing
    /// operation. Called when a view needs the image as soon as possible.
    func requestImage(for item: PhotoItem, size: ImageSize) {
        let key = imageKey(for: item, size: size)
        guard cache.image(for: item, size: size) == nil else { return }
        if let op = imageOps[key] {
            op.queuePriority = requestPriority(for: size)
            return
        }
        enqueueLoad(for: item, size: size, key: key, priority: requestPriority(for: size))
    }

    /// Drops an image back to prefetch priority. Called when the view showing
    /// it leaves the screen.
    func deprioritizeImage(for item: PhotoItem, size: ImageSize) {
        imageOps[imageKey(for: item, size: size)]?.queuePriority = prefetchPriority(for: size)
    }

    /// Starts loading an image at low priority if not already in flight.
    func prefetchImage(for item: PhotoItem, size: ImageSize) {
        let key = imageKey(for: item, size: size)
        guard cache.image(for: item, size: size) == nil, imageOps[key] == nil else { return }
        enqueueLoad(for: item, size: size, key: key, priority: prefetchPriority(for: size))
    }

    /// Queues background loads for all items. Cancels any previous prefetch ops
    /// that have not been promoted by a user request.
    func prefetchImages(for items: [PhotoItem], size: ImageSize) {
        cancelIdlePrefetch(size: size)
        for item in items {
            prefetchImage(for: item, size: size)
        }
    }

    // MARK: - Private

    private func requestPriority(for size: ImageSize) -> Operation.QueuePriority {
        switch size {
        case .full: Self.currentImagePriority
        case .thumbnail: Self.visibleThumbnailPriority
        }
    }

    private func prefetchPriority(for size: ImageSize) -> Operation.QueuePriority {
        switch size {
        case .full: Self.nearbyImagePriority
        case .thumbnail: Self.backgroundPrefetchPriority
        }
    }

    private func imageKey(for item: PhotoItem, size: ImageSize) -> String {
        switch size {
        case let .thumbnail(maxPixelSize): "\(item.id)@\(maxPixelSize)"
        case .full: "\(item.id)@full"
        }
    }

    private func enqueueLoad(for item: PhotoItem, size: ImageSize, key: String, priority: Operation.QueuePriority) {
        let url = item.sourceURL
        imageOps[key] = makeOp(
            priority: priority,
            decode: { [size] in
                switch size {
                case .full: ImageDecoder.fullImage(from: url)
                case let .thumbnail(maxPixelSize): ImageDecoder.thumbnail(from: url, maxPixelSize: maxPixelSize)
                }
            },
            store: { [size] image in ImageLoader.shared.cache.setImage(image, for: item, size: size) },
            onComplete: { ImageLoader.shared.completeImageLoad(key: key, itemID: item.id) }
        )
    }

    private func cancelIdlePrefetch(size: ImageSize) {
        let idlePriority = prefetchPriority(for: size)
        imageOps = imageOps.filter { _, op in
            if op.queuePriority == idlePriority {
                op.cancel()
                return false
            }
            return true
        }
    }

    private func completeImageLoad(key: String, itemID: UUID) {
        imageOps.removeValue(forKey: key)
        NotificationCenter.default.post(
            name: ImageLoader.imageLoadedNotification,
            object: nil,
            userInfo: [ImageLoader.imageLoadedItemIDKey: itemID]
        )
    }

    private func makeOp(
        priority: Operation.QueuePriority,
        decode: @escaping @Sendable () -> CGImage?,
        store: @escaping @MainActor (NSImage) -> Void,
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
