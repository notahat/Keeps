/// Figures on how well image loading is keeping up, for the debug overlay
/// (ImageStatisticsOverlay). Two kinds of event feed it:
///
/// - A lookup is a view asking for an image, which is a hit when the image
///   is already cached.
/// - A step is the user moving to a photo at full size. It's sharp straight
///   away when the full image was already cached, sharp after a while when
///   the user waits for it to load, or moved on when the user steps away
///   before it loads.
///
/// Only the most recent steps count, so the figures follow what the user
/// is doing now. Pure: it measures nothing itself.
nonisolated struct ImageLoadStatistics {
    /// How a step to a photo at full size ended.
    enum StepOutcome: Equatable {
        /// The full image showed after this long; zero when it was cached.
        case sharp(after: Duration)

        /// The user moved on before the full image loaded.
        case movedOn
    }

    /// How many steps the figures cover.
    static let recentStepLimit = 50

    /// How many lookups found their image cached.
    private(set) var hitCount = 0

    /// How many lookups found their image missing from the cache.
    private(set) var missCount = 0

    /// The most recent steps, oldest first.
    private var recentSteps: [StepOutcome] = []

    /// Count a view asking for an image, and whether the image was cached.
    mutating func recordLookup(isHit: Bool) {
        if isHit {
            hitCount += 1
        } else {
            missCount += 1
        }
    }

    /// Add a step, forgetting the oldest once there are more than
    /// recentStepLimit.
    mutating func recordStep(_ outcome: StepOutcome) {
        recentSteps.append(outcome)
        if recentSteps.count > Self.recentStepLimit {
            recentSteps.removeFirst()
        }
    }

    /// The share of lookups that found the image cached, or nil before any
    /// lookups.
    var hitRate: Double? {
        let lookupCount = hitCount + missCount
        guard lookupCount > 0 else { return nil }
        return Double(hitCount) / Double(lookupCount)
    }

    /// The share of recent steps that were sharp straight away, or nil
    /// before any steps.
    var sharpStraightAwayShare: Double? {
        guard !recentSteps.isEmpty else { return nil }
        let immediateCount = recentSteps.count { $0 == .sharp(after: .zero) }
        return Double(immediateCount) / Double(recentSteps.count)
    }

    /// The median time the recent steps took to turn sharp, or nil when
    /// none did. Of an even number, the lower of the middle two.
    var medianTimeToSharp: Duration? {
        let times = timesToSharp.sorted()
        guard !times.isEmpty else { return nil }
        return times[(times.count - 1) / 2]
    }

    /// The longest a recent step took to turn sharp, or nil when none did.
    var slowestTimeToSharp: Duration? {
        timesToSharp.max()
    }

    /// How many recent steps the user moved on from before they turned
    /// sharp.
    var movedOnCount: Int {
        recentSteps.count { $0 == .movedOn }
    }

    /// The times of the recent steps that turned sharp.
    private var timesToSharp: [Duration] {
        recentSteps.compactMap { outcome in
            guard case let .sharp(after: time) = outcome else { return nil }
            return time
        }
    }
}
