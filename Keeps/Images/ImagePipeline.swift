import AppKit
import Observation
import os

/// The image of one photo at one size, for a view to show. `image` is nil
/// until the image has loaded. The view reads `image` in its body, so
/// SwiftUI redraws the view when the image arrives. Each image has its own
/// WatchedImage, so a load redraws only the views showing that image, rather
/// than every view on screen.
@Observable
final class WatchedImage {
    /// The image, or nil until it loads.
    fileprivate(set) var image: NSImage?

    /// Make a WatchedImage holding the image, if it has already loaded.
    fileprivate init(image: NSImage?) {
        self.image = image
    }
}

/// Schedules image reads and caches the results. Every read goes through a
/// bounded OperationQueue at one of four priorities: full images on screen,
/// then full images read ahead, then scaled images on screen, then scaled
/// images read ahead. Full images are on screen in the full-size view and
/// in the largest tiles, which only small groups have, so only a few are
/// asked for at once. A view gets a WatchedImage from
/// `watchedImage(for:size:)` and reads its image in its body, so the view
/// redraws when the image loads, without suspending on async/await. It
/// doesn't decode files itself (that's ImageReader's job) or draw anything.
@Observable
@MainActor
final class ImagePipeline {
    /// The pipeline every view uses, so they all share one cache and one
    /// queue of reads.
    static let shared = ImagePipeline()

    /// Full images on screen, which go ahead of everything.
    private static let visibleFullImagePriority: Operation.QueuePriority = .veryHigh

    /// Full images read ahead, such as the full-size view's neighbours, or
    /// whose tile has left the screen.
    private static let fullImagePrefetchPriority: Operation.QueuePriority = .high

    /// Scaled images on screen, such as thumbnails and medium images. Low
    /// rather than normal so that full-size reads always pre-empt them.
    private static let visibleScaledImagePriority: Operation.QueuePriority = .low

    /// Scaled images read ahead in the background.
    private static let backgroundPrefetchPriority: Operation.QueuePriority = .veryLow

    /// The images read so far, until memory pressure evicts them.
    private let cache = ImageCache()

    /// Where reads that fail are logged. A file that can't be read leaves
    /// its view showing a placeholder, so the log says why.
    private static let logger = Logger(subsystem: "com.notahat.Keeps", category: "Image loading")

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

    /// Every read queued or running, at any priority, by photo and size.
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
    private(set) var statistics = ImageLoadStatistics()

    // MARK: - Public interface

    /// Return a photo's cached image at a size immediately, or nil if it
    /// isn't cached.
    func cachedImage(for photo: PhotoItem, size: ImageSize) -> NSImage? {
        cache.image(for: photo, size: size)
    }

    /// Return the WatchedImage for a photo's image at a size. The
    /// WatchedImage already holds the image if the image is cached. The
    /// calling view must keep the WatchedImage in its @State, since the
    /// pipeline holds only a weak reference to it. This doesn't start a
    /// read; use requestImage or prefetchImage for that.
    func watchedImage(for photo: PhotoItem, size: ImageSize) -> WatchedImage {
        let key = readKey(for: photo, size: size) as NSString
        if let existing = watchedImages.object(forKey: key) {
            recordLookup(of: size, isHit: existing.image != nil)
            return existing
        }
        let watchedImage = WatchedImage(image: cache.image(for: photo, size: size))
        recordLookup(of: size, isHit: watchedImage.image != nil)
        watchedImages.setObject(watchedImage, forKey: key)
        return watchedImage
    }

    /// Start reading an image at the priority for what's on screen, or raise
    /// an existing read to it, unless the image is already cached. Called
    /// when a view needs the image as soon as possible.
    func requestImage(for photo: PhotoItem, size: ImageSize) {
        guard cache.image(for: photo, size: size) == nil else { return }
        let key = readKey(for: photo, size: size)
        if let read = readsInFlight[key] {
            read.queuePriority = requestPriority(for: size)
            return
        }
        enqueueRead(of: photo, size: size, key: key, priority: requestPriority(for: size))
    }

    /// Drop a read back to prefetch priority, if there's one in flight.
    /// Called when the view showing its image leaves the screen.
    func deprioritizeImage(for photo: PhotoItem, size: ImageSize) {
        readsInFlight[readKey(for: photo, size: size)]?.queuePriority = prefetchPriority(for: size)
    }

    /// Start reading an image at prefetch priority, unless it's already
    /// cached or being read.
    func prefetchImage(for photo: PhotoItem, size: ImageSize) {
        let key = readKey(for: photo, size: size)
        guard cache.image(for: photo, size: size) == nil, readsInFlight[key] == nil else { return }
        enqueueRead(of: photo, size: size, key: key, priority: prefetchPriority(for: size))
    }

    /// Queue background reads for all the photos, first cancelling any
    /// earlier prefetches that no view has asked for since.
    func prefetchImages(for photos: [PhotoItem], size: ImageSize) {
        cancelIdlePrefetches(size: size)
        for photo in photos {
            prefetchImage(for: photo, size: size)
        }
    }

    /// Record how a step to a photo at full size ended, for the debug
    /// overlay.
    func recordStep(_ outcome: ImageLoadStatistics.StepOutcome) {
        statistics.recordStep(outcome)
    }

    /// Return what's cached at each size, for the debug overlay.
    func cacheContents() -> [ImageCache.Contents] {
        cache.contents()
    }

    /// How many reads are queued or running, for the debug overlay.
    var readCount: Int {
        readsInFlight.count
    }

    /// Read an image and cache it straight away, blocking until it's loaded.
    /// Only for SwiftUI previews, which are drawn before a background read
    /// would finish; in the app a blocking read would stall the main thread.
    /// Stop the preview with a fatal error if the file can't be read.
    func loadImageImmediately(for photo: PhotoItem, size: ImageSize) {
        guard let cgImage = ImageReader.readImage(from: photo.sourceURL, size: size) else {
            fatalError("Couldn't read the preview photo \(photo.sourceURL.lastPathComponent)")
        }
        store(NSImage(cgImage: cgImage, size: .zero), for: photo, size: size)
    }

    // MARK: - Private

    /// Count a view asking for an image for the debug overlay, and mark the
    /// lookup for Instruments.
    private func recordLookup(of size: ImageSize, isHit: Bool) {
        statistics.recordLookup(isHit: isHit)
        ImageSignposts.markLookup(of: size, isHit: isHit)
    }

    /// Return the priority for an image a view is showing.
    private func requestPriority(for size: ImageSize) -> Operation.QueuePriority {
        switch size {
        case .full: Self.visibleFullImagePriority
        case .scaled: Self.visibleScaledImagePriority
        }
    }

    /// Return the priority for an image read ahead of being shown.
    private func prefetchPriority(for size: ImageSize) -> Operation.QueuePriority {
        switch size {
        case .full: Self.fullImagePrefetchPriority
        case .scaled: Self.backgroundPrefetchPriority
        }
    }

    /// Return the key a read is tracked by: the photo and the size.
    private func readKey(for photo: PhotoItem, size: ImageSize) -> String {
        switch size {
        case let .scaled(longestSideLength): "\(photo.id)@\(longestSideLength)"
        case .full: "\(photo.id)@full"
        }
    }

    /// Queue a read of a photo's image, which finishes back on the main
    /// actor (see finishRead).
    private func enqueueRead(
        of photo: PhotoItem,
        size: ImageSize,
        key: String,
        priority: Operation.QueuePriority
    ) {
        let url = photo.sourceURL
        let enqueueTime = ContinuousClock.now
        let read = BlockOperation {
            let cgImage = ImageSignposts.markRead(of: size, queuedSince: enqueueTime) {
                ImageReader.readImage(from: url, size: size)
            }
            Task { @MainActor in
                self.finishRead(of: photo, size: size, key: key, cgImage: cgImage)
            }
        }
        read.queuePriority = priority
        readsInFlight[key] = read
        readQueue.addOperation(read)
    }

    /// Store a finished read's image, or log that the file gave none, and
    /// stop tracking the read.
    private func finishRead(of photo: PhotoItem, size: ImageSize, key: String, cgImage: CGImage?) {
        if let cgImage {
            store(NSImage(cgImage: cgImage, size: .zero), for: photo, size: size)
        } else {
            Self.logger.error("Couldn't read \(photo.sourceURL.path, privacy: .public) at \(size, privacy: .public)")
        }
        readsInFlight.removeValue(forKey: key)
    }

    /// Cache a loaded image, and hand it to the WatchedImage for it if a view
    /// is watching, which redraws only the views showing the image.
    private func store(_ image: NSImage, for photo: PhotoItem, size: ImageSize) {
        cache.setImage(image, for: photo, size: size)
        watchedImages.object(forKey: readKey(for: photo, size: size) as NSString)?.image = image
    }

    /// Cancel the reads still at prefetch priority for a size: those no view
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
