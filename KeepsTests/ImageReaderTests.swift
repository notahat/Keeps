@testable import Keeps
import Testing

struct ImageReaderTests {
    @Test("A side too long for the limit is halved")
    func halvesOnce() {
        #expect(ImageReader.halvedSize(of: 7728, toAtMost: 4416) == 3864)
    }

    @Test("A side within the limit stays as it is")
    func staysWithinLimit() {
        #expect(ImageReader.halvedSize(of: 4000, toAtMost: 4416) == 4000)
    }

    @Test("A side far too long is halved until it fits")
    func halvesUntilItFits() {
        #expect(ImageReader.halvedSize(of: 20000, toAtMost: 4416) == 2500)
    }

    @Test("Halving an odd side rounds down")
    func roundsDown() {
        #expect(ImageReader.halvedSize(of: 7729, toAtMost: 4416) == 3864)
    }
}
