@testable import Keeps
import Testing

struct ImageLoadStatisticsTests {
    @Test("Has no hit rate before any lookups")
    func noHitRateWithoutLookups() {
        let statistics = ImageLoadStatistics()

        #expect(statistics.hitRate == nil)
    }

    @Test("The hit rate is the share of lookups that found the image cached")
    func hitRate() {
        var statistics = ImageLoadStatistics()

        statistics.recordLookup(isHit: true)
        statistics.recordLookup(isHit: true)
        statistics.recordLookup(isHit: true)
        statistics.recordLookup(isHit: false)

        #expect(statistics.hitRate == 0.75)
    }

    @Test("Has no step figures before any steps")
    func noStepFiguresWithoutSteps() {
        let statistics = ImageLoadStatistics()

        #expect(statistics.sharpStraightAwayShare == nil)
        #expect(statistics.medianTimeToSharp == nil)
        #expect(statistics.slowestTimeToSharp == nil)
        #expect(statistics.movedOnCount == 0)
    }

    @Test("Counts a step that took no time as sharp straight away")
    func sharpStraightAwayShare() {
        var statistics = ImageLoadStatistics()

        statistics.recordStep(.sharp(after: .zero))
        statistics.recordStep(.sharp(after: .milliseconds(80)))
        statistics.recordStep(.sharp(after: .zero))
        statistics.recordStep(.movedOn)

        #expect(statistics.sharpStraightAwayShare == 0.5)
    }

    @Test("Gives the median and slowest times of the steps that turned sharp")
    func medianAndSlowest() {
        var statistics = ImageLoadStatistics()

        statistics.recordStep(.sharp(after: .milliseconds(30)))
        statistics.recordStep(.sharp(after: .milliseconds(200)))
        statistics.recordStep(.movedOn)
        statistics.recordStep(.sharp(after: .milliseconds(10)))

        #expect(statistics.medianTimeToSharp == .milliseconds(30))
        #expect(statistics.slowestTimeToSharp == .milliseconds(200))
    }

    @Test("Counts the steps moved on from before they turned sharp")
    func movedOnCount() {
        var statistics = ImageLoadStatistics()

        statistics.recordStep(.movedOn)
        statistics.recordStep(.sharp(after: .zero))
        statistics.recordStep(.movedOn)

        #expect(statistics.movedOnCount == 2)
    }

    @Test("Keeps only the most recent steps")
    func keepsRecentSteps() {
        var statistics = ImageLoadStatistics()

        statistics.recordStep(.sharp(after: .seconds(5)))
        for _ in 0 ..< ImageLoadStatistics.recentStepLimit {
            statistics.recordStep(.sharp(after: .zero))
        }

        #expect(statistics.slowestTimeToSharp == .zero)
        #expect(statistics.sharpStraightAwayShare == 1)
    }
}
