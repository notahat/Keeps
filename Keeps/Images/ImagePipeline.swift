import AppKit
import Observation
import SwiftUI

/// Schedules image reads and caches the results. Every read goes through a
/// bounded OperationQueue at one of four priorities: the full-size image
/// being looked at, then the full-size images near it, then thumbnails on
/// screen, then background prefetching. Views hear that an image has loaded
/// through `onImageLoaded(for:)`, so they update without suspending on
/// async/await. Doesn't decode files itself (that's ImageReader's job) or
/// draw anything.
@Observable
@MainActor
final class ImagePipeline {
    static let shared = ImagePipeline()

    /// Posted on the main thread when any image finishes loading, with the
    /// item's id in the userInfo under `loadedItemIDKey`. Heard through
    /// `onImageLoaded(for:)`.
    fileprivate static let imageLoadedNotification = Notification.Name("com.notahat.Keeps.imageLoaded")
    fileprivate static let loadedItemIDKey = "itemID"

    /// The full-size image being looked at, which goes ahead of everything.
    private static let currentImagePriority: Operation.QueuePriority = .veryHigh

    /// The full-size images either side of it, read ahead.
    private static let nearbyImagePriority: Operation.QueuePriority = .high

    /// Thumbnails on screen. Low rather than normal so that full-size reads
    /// always pre-empt them.
    private static let visibleThumbnailPriority: Operation.QueuePriority = .low

    /// Thumbnails read ahead in the background.
    private static let backgroundPrefetchPriority: Operation.QueuePriority = .veryLow

    private let cache = ImageCache()

    /// The worker pool. Its concurrency balances throughput against memory
    /// and responsiveness.
    private let readQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.notahat.Keeps.ImagePipeline"
        queue.maxConcurrentOperationCount = 16
        return queue
    }()

    /// Every read queued or running, at any priority, by item and size.
    private var readsInFlight: [String: Operation] = [:]

    /// How many reads are queued or running.
    var queueCount: Int {
        readsInFlight.count
    }

    // MARK: - Public interface

    /// Returns the cached image immediately, or nil if not yet loaded.
    func cachedImage(for item: PhotoItem, size: ImageSize) -> NSImage? {
        cache.image(for: item, size: size)
    }

    /// Starts reading an image at the priority for what's on screen, or
    /// raises an existing read to it. Called when a view needs the image as
    /// soon as possible.
    func requestImage(for item: PhotoItem, size: ImageSize) {
        guard cache.image(for: item, size: size) == nil else { return }
        let key = readKey(for: item, size: size)
        if let read = readsInFlight[key] {
            read.queuePriority = requestPriority(for: size)
            return
        }
        enqueueRead(of: item, size: size, key: key, priority: requestPriority(for: size))
    }

    /// Drops a read back to prefetch priority. Called when the view showing
    /// its image leaves the screen.
    func deprioritizeImage(for item: PhotoItem, size: ImageSize) {
        readsInFlight[readKey(for: item, size: size)]?.queuePriority = prefetchPriority(for: size)
    }

    /// Starts reading an image at prefetch priority, unless it's already
    /// cached or being read.
    func prefetchImage(for item: PhotoItem, size: ImageSize) {
        let key = readKey(for: item, size: size)
        guard cache.image(for: item, size: size) == nil, readsInFlight[key] == nil else { return }
        enqueueRead(of: item, size: size, key: key, priority: prefetchPriority(for: size))
    }

    /// Queues background reads for all items, first cancelling any earlier
    /// prefetches that no view has asked for since.
    func prefetchImages(for items: [PhotoItem], size: ImageSize) {
        cancelIdlePrefetches(size: size)
        for item in items {
            prefetchImage(for: item, size: size)
        }
    }

    /// Reads an image and caches it straight away, blocking until it's
    /// loaded. Only for SwiftUI previews, which are drawn before a background
    /// read would finish; in the app it would stall the main thread.
    func loadImageImmediately(for item: PhotoItem, size: ImageSize) {
        guard let cgImage = Self.readImage(from: item.sourceURL, size: size) else { return }
        cache.setImage(NSImage(cgImage: cgImage, size: .zero), for: item, size: size)
    }

    // MARK: - Private

    /// The priority for an image a view is showing.
    private func requestPriority(for size: ImageSize) -> Operation.QueuePriority {
        switch size {
        case .full: Self.currentImagePriority
        case .thumbnail: Self.visibleThumbnailPriority
        }
    }

    /// The priority for an image read ahead of being shown.
    private func prefetchPriority(for size: ImageSize) -> Operation.QueuePriority {
        switch size {
        case .full: Self.nearbyImagePriority
        case .thumbnail: Self.backgroundPrefetchPriority
        }
    }

    /// The key a read is tracked by: the item and the size.
    private func readKey(for item: PhotoItem, size: ImageSize) -> String {
        switch size {
        case let .thumbnail(maxPixelSize): "\(item.id)@\(maxPixelSize)"
        case .full: "\(item.id)@full"
        }
    }

    /// Reads an image of the given size from a file. Safe on any thread.
    private nonisolated static func readImage(from url: URL, size: ImageSize) -> CGImage? {
        switch size {
        case .full: ImageReader.fullImage(from: url)
        case let .thumbnail(maxPixelSize): ImageReader.thumbnail(from: url, maxPixelSize: maxPixelSize)
        }
    }

    /// Queues a read of an item's image, which finishes back on the main
    /// actor (see finishRead).
    private func enqueueRead(
        of item: PhotoItem,
        size: ImageSize,
        key: String,
        priority: Operation.QueuePriority
    ) {
        let url = item.sourceURL
        let read = BlockOperation {
            let cgImage = Self.readImage(from: url, size: size)
            Task { @MainActor in
                self.finishRead(of: item, size: size, key: key, cgImage: cgImage)
            }
        }
        read.queuePriority = priority
        readsInFlight[key] = read
        readQueue.addOperation(read)
    }

    /// Caches a finished read's image, if the file gave one, stops tracking
    /// the read, and tells views the item's image has loaded.
    private func finishRead(of item: PhotoItem, size: ImageSize, key: String, cgImage: CGImage?) {
        if let cgImage {
            cache.setImage(NSImage(cgImage: cgImage, size: .zero), for: item, size: size)
        }
        readsInFlight.removeValue(forKey: key)
        NotificationCenter.default.post(
            name: Self.imageLoadedNotification,
            object: nil,
            userInfo: [Self.loadedItemIDKey: item.id]
        )
    }

    /// Cancels the reads still at prefetch priority for a size: those no view
    /// has asked for, or that went back to prefetch priority when their view
    /// left the screen.
    private func cancelIdlePrefetches(size: ImageSize) {
        let idlePriority = prefetchPriority(for: size)
        readsInFlight = readsInFlight.filter { _, read in
            guard read.queuePriority == idlePriority else { return true }
            read.cancel()
            return false
        }
    }
}

extension View {
    /// Runs `action` each time an image of `item` finishes loading, at any
    /// size. The image is then in the pipeline's cache.
    func onImageLoaded(for item: PhotoItem, perform action: @escaping () -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: ImagePipeline.imageLoadedNotification)) { notification in
            guard notification.userInfo?[ImagePipeline.loadedItemIDKey] as? UUID == item.id else { return }
            action()
        }
    }
}
