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

    @Test("Has no share sharp straight away before any steps")
    func noSharpShareWithoutSteps() {
        let statistics = ImageLoadStatistics()

        #expect(statistics.sharpStraightAwayShare == nil)
    }

    @Test("Has no median time to sharp before any steps")
    func noMedianWithoutSteps() {
        let statistics = ImageLoadStatistics()

        #expect(statistics.medianTimeToSharp == nil)
    }

    @Test("Has no slowest time to sharp before any steps")
    func noSlowestWithoutSteps() {
        let statistics = ImageLoadStatistics()

        #expect(statistics.slowestTimeToSharp == nil)
    }

    @Test("Counts no steps moved on before any steps")
    func noMovedOnWithoutSteps() {
        let statistics = ImageLoadStatistics()

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

    @Test("Gives the median time of the steps that turned sharp")
    func medianTimeToSharp() {
        var statistics = ImageLoadStatistics()

        statistics.recordStep(.sharp(after: .milliseconds(30)))
        statistics.recordStep(.sharp(after: .milliseconds(200)))
        statistics.recordStep(.movedOn)
        statistics.recordStep(.sharp(after: .milliseconds(10)))

        #expect(statistics.medianTimeToSharp == .milliseconds(30))
    }

    @Test("Gives the slowest time of the steps that turned sharp")
    func slowestTimeToSharp() {
        var statistics = ImageLoadStatistics()

        statistics.recordStep(.sharp(after: .milliseconds(30)))
        statistics.recordStep(.sharp(after: .milliseconds(200)))
        statistics.recordStep(.movedOn)

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
    }
}
