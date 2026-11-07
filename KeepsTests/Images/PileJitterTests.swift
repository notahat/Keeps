import Foundation
@testable import Keeps
import Testing

struct PileJitterTests {
    @Test("The same photo always lands the same way")
    func sameStemSameJitter() {
        #expect(PileJitter(stem: "IMG_0042") == PileJitter(stem: "IMG_0042"))
    }

    @Test("Different photos land differently")
    func differentStemsDiffer() {
        #expect(PileJitter(stem: "IMG_0042") != PileJitter(stem: "IMG_0043"))
    }

    @Test("Rotation and offset stay within their limits")
    func jitterWithinLimits() {
        for index in 0 ..< 200 {
            let jitter = PileJitter(stem: "IMG_\(index)")

            #expect(abs(jitter.rotationDegrees) <= PileJitter.maximumRotationDegrees)
            #expect(abs(jitter.horizontalOffset) <= PileJitter.maximumOffset)
            #expect(abs(jitter.verticalOffset) <= PileJitter.maximumOffset)
        }
    }

    @Test("Jitter actually varies across photos rather than sitting at zero")
    func jitterVaries() {
        let rotations = (0 ..< 50).map { PileJitter(stem: "IMG_\($0)").rotationDegrees }

        #expect(Set(rotations).count > 40)
    }
}
