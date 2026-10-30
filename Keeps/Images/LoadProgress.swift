import Foundation

/// How far through the current burst of image loading the pipeline is. A
/// burst runs from when work is first queued until the queue empties; its
/// total counts every load queued during it, including ones added partway.
/// Pure.
nonisolated struct LoadProgress {
    private var totalQueued = 0
    private var remaining = 0

    /// The fraction of the burst done, from 0 to 1, or nil when nothing is
    /// loading.
    var fractionComplete: Double? {
        guard remaining > 0, totalQueued > 0 else { return nil }
        return Double(totalQueued - remaining) / Double(totalQueued)
    }

    /// Updates the progress from the number of loads still queued or
    /// running. A rise means new work joined the burst.
    mutating func record(queueCount: Int) {
        if queueCount == 0 {
            totalQueued = 0
        } else if queueCount > remaining {
            totalQueued += queueCount - remaining
        }
        remaining = queueCount
    }
}
