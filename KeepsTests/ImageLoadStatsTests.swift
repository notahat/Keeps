@testable import Keeps
import Testing

struct ImageLoadStatsTests {
    @Test("Has no hit rate before any lookups")
    func noHitRateWithoutLookups() {
        let stats = ImageLoadStats()

        #expect(stats.hitRate == nil)
    }

    @Test("The hit rate is the share of lookups that found the image cached")
    func hitRate() {
        var stats = ImageLoadStats()

        stats.recordLookup(isHit: true)
        stats.recordLookup(isHit: true)
        stats.recordLookup(isHit: true)
        stats.recordLookup(isHit: false)

        #expect(stats.hitRate == 0.75)
    }

    @Test("Has no step figures before any steps")
    func noStepFiguresWithoutSteps() {
        let stats = ImageLoadStats()

        #expect(stats.sharpStraightAwayShare == nil)
        #expect(stats.medianTimeToSharp == nil)
        #expect(stats.slowestTimeToSharp == nil)
        #expect(stats.movedOnCount == 0)
    }

    @Test("Counts a step that took no time as sharp straight away")
    func sharpStraightAwayShare() {
        var stats = ImageLoadStats()

        stats.recordStep(.sharp(after: .zero))
        stats.recordStep(.sharp(after: .milliseconds(80)))
        stats.recordStep(.sharp(after: .zero))
        stats.recordStep(.movedOn)

        #expect(stats.sharpStraightAwayShare == 0.5)
    }

    @Test("Gives the median and slowest times of the steps that turned sharp")
    func medianAndSlowest() {
        var stats = ImageLoadStats()

        stats.recordStep(.sharp(after: .milliseconds(30)))
        stats.recordStep(.sharp(after: .milliseconds(200)))
        stats.recordStep(.movedOn)
        stats.recordStep(.sharp(after: .milliseconds(10)))

        #expect(stats.medianTimeToSharp == .milliseconds(30))
        #expect(stats.slowestTimeToSharp == .milliseconds(200))
    }

    @Test("Counts the steps moved on from before they turned sharp")
    func movedOnCount() {
        var stats = ImageLoadStats()

        stats.recordStep(.movedOn)
        stats.recordStep(.sharp(after: .zero))
        stats.recordStep(.movedOn)

        #expect(stats.movedOnCount == 2)
    }

    @Test("Keeps only the most recent steps")
    func keepsRecentSteps() {
        var stats = ImageLoadStats()

        stats.recordStep(.sharp(after: .seconds(5)))
        for _ in 0 ..< ImageLoadStats.recentStepLimit {
            stats.recordStep(.sharp(after: .zero))
        }

        #expect(stats.slowestTimeToSharp == .zero)
        #expect(stats.sharpStraightAwayShare == 1)
    }
}
