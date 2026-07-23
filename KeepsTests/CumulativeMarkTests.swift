import Foundation
@testable import Keeps
import Testing

struct CumulativeMarkTests {
    @Test func returnsNilForUnmarkedPhoto() throws {
        let library = makeLibrary(photoCount: 3)

        #expect(library.cumulativeMark(for: library.items[0].id) == nil)
    }

    @Test func returnsPickFromSinglePass() throws {
        let library = makeLibrary(photoCount: 3)

        library.setMark(.pick, for: library.items[0])

        #expect(library.cumulativeMark(for: library.items[0].id) == .pick)
    }

    @Test func returnsRejectFromSinglePass() throws {
        let library = makeLibrary(photoCount: 3)

        library.setMark(.reject, for: library.items[0])

        #expect(library.cumulativeMark(for: library.items[0].id) == .reject)
    }

    @Test func lastPassWinsWhenMarkedInMultiplePasses() throws {
        let library = makeLibrary(photoCount: 3)

        library.setMark(.reject, for: library.items[0])
        library.startNextPass()
        library.setMark(.pick, for: library.items[0])

        #expect(library.cumulativeMark(for: library.items[0].id) == .pick)
    }

    @Test func sortPlanGroupsByMark() throws {
        let library = makeLibrary(photoCount: 3)

        library.setMark(.pick, for: library.items[0])
        library.setMark(.reject, for: library.items[1])

        let plan = library.sortPlan()

        #expect(plan[.pick]?.count == 1)
        #expect(plan[.pick]?.first?.id == library.items[0].id)
        #expect(plan[.reject]?.count == 1)
        #expect(plan[.reject]?.first?.id == library.items[1].id)
        #expect(plan[nil]?.count == 1)
        #expect(plan[nil]?.first?.id == library.items[2].id)
    }
}
