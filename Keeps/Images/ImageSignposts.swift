import CoreGraphics
import os

/// Marks image loading for Instruments, so a recording shows each read,
/// cache event, and step at full size on a timeline beside CPU, memory, and
/// hangs. They show in the os_signpost instrument, under the Keeps
/// subsystem's "Image loading" category.
///
/// Three kinds of mark:
///
/// - A read is an interval around decoding one image, labelled with the
///   size asked for and how long the read waited in the queue first, and
///   ending with the pixel size decoded.
/// - Cache hits, misses, and evictions are events.
/// - A step is an interval from the user moving to a photo at full size
///   until its full image shows, ending "sharp", or "moved on" when the
///   user steps away first. A step whose image is already cached is an
///   event instead.
///
/// Signposts cost next to nothing when nothing is recording, so they stay
/// in release builds. ImageSignposts only marks; ImageLoadStatistics keeps
/// the figures the debug overlay shows.
nonisolated enum ImageSignposts {
    /// Where every mark goes: the Keeps subsystem's "Image loading"
    /// category.
    private static let signposter = OSSignposter(subsystem: "com.notahat.Keeps", category: "Image loading")

    /// Run a read of an image, marking the read as an interval, and return
    /// what the read returned. The queue wait is a label rather than an
    /// interval of its own, because a read that's cancelled while queued
    /// never runs to end one.
    static func markRead(
        of size: ImageSize,
        queuedSince enqueueTime: ContinuousClock.Instant,
        _ read: () -> CGImage?
    ) -> CGImage? {
        let waitMilliseconds = Int((.now - enqueueTime) / .milliseconds(1))
        let state = signposter.beginInterval(
            "Read", id: signposter.makeSignpostID(),
            "\(size.description, privacy: .public), queued \(waitMilliseconds) ms"
        )
        let image = read()
        let decodedSize = image.map { "\($0.width) × \($0.height)" } ?? "failed"
        signposter.endInterval("Read", state, "\(decodedSize, privacy: .public)")
        return image
    }

    /// Mark a view asking the cache for an image, and whether the image was
    /// there.
    static func markLookup(of size: ImageSize, isHit: Bool) {
        if isHit {
            signposter.emitEvent("Cache hit", "\(size.description, privacy: .public)")
        } else {
            signposter.emitEvent("Cache miss", "\(size.description, privacy: .public)")
        }
    }

    /// Mark the cache evicting an image.
    static func markEviction(of size: ImageSize) {
        signposter.emitEvent("Cache eviction", "\(size.description, privacy: .public)")
    }

    /// Mark a step to a photo whose full image is already cached.
    static func markSharpStep(to stem: String) {
        signposter.emitEvent("Step sharp at once", "\(stem, privacy: .public)")
    }

    /// Begin the interval of a step to a photo whose full image is still
    /// loading. Pass the returned state to endStep to end the interval.
    static func beginStep(to stem: String) -> OSSignpostIntervalState {
        signposter.beginInterval("Step", id: signposter.makeSignpostID(), "\(stem, privacy: .public)")
    }

    /// End a step's interval, saying whether the image turned sharp or the
    /// user moved on first.
    static func endStep(_ state: OSSignpostIntervalState, isSharp: Bool) {
        signposter.endInterval("Step", state, "\(isSharp ? "sharp" : "moved on", privacy: .public)")
    }
}
