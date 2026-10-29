import Foundation
@testable import Keeps
import Testing

struct LoadProgressTests {
    @Test("Nothing is in progress when nothing is queued")
    func idleWhenEmpty() {
        let progress = LoadProgress()

        #expect(progress.fractionComplete == nil)
    }

    @Test("A burst starts at zero")
    func burstStartsEmpty() {
        var progress = LoadProgress()

        progress.record(queueCount: 10)

        #expect(progress.fractionComplete == 0)
    }

    @Test("Progress rises as the queue drains")
    func risesAsQueueDrains() {
        var progress = LoadProgress()
        progress.record(queueCount: 10)

        progress.record(queueCount: 4)

        #expect(progress.fractionComplete == 0.6)
    }

    @Test("Work added mid-burst counts towards the total")
    func addedWorkGrowsTotal() {
        var progress = LoadProgress()
        progress.record(queueCount: 10)
        progress.record(queueCount: 5)

        progress.record(queueCount: 15)
        progress.record(queueCount: 10)

        // Ten queued, then ten more added once five were done: twenty in
        // all, ten done.
        #expect(progress.fractionComplete == 0.5)
    }

    @Test("When the queue empties the burst ends, and the next one starts afresh")
    func burstResetsWhenEmpty() {
        var progress = LoadProgress()
        progress.record(queueCount: 10)
        progress.record(queueCount: 0)

        progress.record(queueCount: 2)

        #expect(progress.fractionComplete == 0)
    }
}
