import AppKit
import Observation

/// The image of one photo at one size, for a view to show. `image` is nil
/// until the image has loaded. The view reads `image` in its body, so
/// SwiftUI redraws the view when the image arrives. Each image has its own
/// WatchedImage, so a load redraws only the views showing that image, rather
/// than every view on screen.
@Observable
final class WatchedImage {
    fileprivate(set) var image: NSImage?

    /// Makes a WatchedImage holding the image, if it has already loaded.
    fileprivate init(image: NSImage?) {
        self.image = image
    }
}

/// Schedules image reads and caches the results. Every read goes through a
/// bounded OperationQueue at one of four priorities: the full-size image
/// being looked at, then the full-size images near it, then thumbnails on
/// screen, then background prefetching. A view gets a WatchedImage from
/// `watchedImage(for:size:)` and reads its image in its body, so the view
/// redraws when the image loads, without suspending on async/await. It
/// doesn't decode files itself (that's ImageReader's job) or draw anything.
@Observable
@MainActor
final class ImagePipeline {
    static let shared = ImagePipeline()

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

    /// The images views are watching, by read key. Each one is held weakly,
    /// so it goes once no view holds it. Holding them strongly would keep
    /// every image ever shown in memory, whatever the cache had evicted.
    @ObservationIgnored
    private let watchedImages = NSMapTable<NSString, WatchedImage>.strongToWeakObjects()

    /// The worker pool. Its concurrency balances throughput against memory
    /// and responsiveness.
    private let readQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.notahat.Keeps.ImagePipeline"
        queue.maxConcurrentOperationCount = 16
        return queue
    }()

    /// Every read queued or running, at any priority, by item and size.
    /// Views watch loadProgress rather than this.
    @ObservationIgnored
    private var readsInFlight: [String: Operation] = [:] {
        didSet { loadProgress.record(queueCount: readsInFlight.count) }
    }

    /// How far through the current burst of reads the pipeline is. It's
    /// updated here as each read starts and finishes, so a view can simply
    /// read it. A view that reacted to each change itself would run several
    /// times a frame when reads finish together.
    private(set) var loadProgress = LoadProgress()

    /// How well loading is keeping up, for the debug overlay. Not observed:
    /// the overlay reads it on a timer, so recording a figure never redraws
    /// a view, which would disturb what's being measured.
    @ObservationIgnored
    private(set) var stats = ImageLoadStats()

    // MARK: - Public interface

    /// Returns the cached image immediately, or nil if not yet loaded.
    func cachedImage(for item: PhotoItem, size: ImageSize) -> NSImage? {
        cache.image(for: item, size: size)
    }

    /// Returns the WatchedImage for an item's image at a size. The
    /// WatchedImage already holds the image if the image is cached. The
    /// calling view must keep the WatchedImage in its @State, since the
    /// pipeline holds only a weak reference to it. This doesn't start a
    /// read; use requestImage or prefetchImage for that.
    func watchedImage(for item: PhotoItem, size: ImageSize) -> WatchedImage {
        let key = readKey(for: item, size: size) as NSString
        if let existing = watchedImages.object(forKey: key) {
            recordLookup(of: size, isHit: existing.image != nil)
            return existing
        }
        let watchedImage = WatchedImage(image: cache.image(for: item, size: size))
        recordLookup(of: size, isHit: watchedImage.image != nil)
        watchedImages.setObject(watchedImage, forKey: key)
        return watchedImage
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

    /// Records how a step to a photo at full size ended, for the debug
    /// overlay.
    func recordStep(_ outcome: ImageLoadStats.StepOutcome) {
        stats.recordStep(outcome)
    }

    /// What's cached at each size, for the debug overlay.
    func cacheContents() -> [ImageCache.Contents] {
        cache.contents()
    }

    /// How many reads are queued or running, for the debug overlay.
    var readCount: Int {
        readsInFlight.count
    }

    /// Reads an image and caches it straight away, blocking until it's
    /// loaded. Only for SwiftUI previews, which are drawn before a background
    /// read would finish; in the app it would stall the main thread.
    func loadImageImmediately(for item: PhotoItem, size: ImageSize) {
        guard let cgImage = ImageReader.image(from: item.sourceURL, size: size) else { return }
        store(NSImage(cgImage: cgImage, size: .zero), for: item, size: size)
    }

    // MARK: - Private

    /// Counts a view asking for an image for the debug overlay, and marks it
    /// for Instruments.
    private func recordLookup(of size: ImageSize, isHit: Bool) {
        stats.recordLookup(isHit: isHit)
        ImageSignposts.markLookup(of: size, isHit: isHit)
    }

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
        case let .thumbnail(longestSideLength): "\(item.id)@\(longestSideLength)"
        case .full: "\(item.id)@full"
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
        let enqueueTime = ContinuousClock.now
        let read = BlockOperation {
            let cgImage = ImageSignposts.markRead(of: size, queuedSince: enqueueTime) {
                ImageReader.image(from: url, size: size)
            }
            Task { @MainActor in
                self.finishRead(of: item, size: size, key: key, cgImage: cgImage)
            }
        }
        read.queuePriority = priority
        readsInFlight[key] = read
        readQueue.addOperation(read)
    }

    /// Stores a finished read's image, if the file gave one, and stops
    /// tracking the read.
    private func finishRead(of item: PhotoItem, size: ImageSize, key: String, cgImage: CGImage?) {
        if let cgImage {
            store(NSImage(cgImage: cgImage, size: .zero), for: item, size: size)
        }
        readsInFlight.removeValue(forKey: key)
    }

    /// Caches a loaded image, and hands it to the WatchedImage for it, if a
    /// view is watching, which redraws only the views showing it.
    private func store(_ image: NSImage, for item: PhotoItem, size: ImageSize) {
        cache.setImage(image, for: item, size: size)
        watchedImages.object(forKey: readKey(for: item, size: size) as NSString)?.image = image
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
