import Foundation

/// How far through the current burst of image loading the pipeline is. A
/// burst runs from when work is first queued until the queue empties; its
/// total counts every load queued during it, including ones added partway.
/// It's a pure value, with no tie to the pipeline, so it can be tested.
nonisolated struct LoadProgress {
    /// How many loads have been queued during the current burst.
    private var totalQueued = 0

    /// How many loads are still queued or running.
    private var remaining = 0

    /// The fraction of the burst done, from 0 to 1, or nil when nothing is
    /// loading.
    var fractionComplete: Double? {
        guard remaining > 0, totalQueued > 0 else { return nil }
        return Double(totalQueued - remaining) / Double(totalQueued)
    }

    /// Update the progress from the number of loads still queued or
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
