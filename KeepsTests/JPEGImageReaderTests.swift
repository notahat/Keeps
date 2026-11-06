@testable import Keeps
import Testing

struct JPEGImageReaderTests {
    @Test("A side too long for the limit is halved")
    func halvesOnce() {
        #expect(JPEGImageReader.halvedSize(of: 7728, toAtMost: 4416) == 3864)
    }

    @Test("A side within the limit stays as it is")
    func staysWithinLimit() {
        #expect(JPEGImageReader.halvedSize(of: 4000, toAtMost: 4416) == 4000)
    }

    @Test("A side far too long is halved until it fits")
    func halvesUntilItFits() {
        #expect(JPEGImageReader.halvedSize(of: 20000, toAtMost: 4416) == 2500)
    }

    @Test("Halving an odd side rounds down")
    func roundsDown() {
        #expect(JPEGImageReader.halvedSize(of: 7729, toAtMost: 4416) == 3864)
    }
}
