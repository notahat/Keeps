@testable import Keeps
import Testing

struct FolderSectionTests {
    @Test("Every section shows while there are done groups and keepers")
    func everySectionShowsWhenAvailable() {
        for section in [FolderSection.toGo, .done, .keepers] {
            #expect(section.availableSection(hasDoneGroups: true, hasKeepers: true) == section)
        }
    }

    @Test("The done section goes back to the sort screen once there are no done groups")
    func doneFallsBackWithoutDoneGroups() {
        let available = FolderSection.done.availableSection(hasDoneGroups: false, hasKeepers: false)

        #expect(available == .toGo)
    }

    @Test("The keepers section goes back to the sort screen once there are no keepers")
    func keepersFallsBackWithoutKeepers() {
        let available = FolderSection.keepers.availableSection(hasDoneGroups: true, hasKeepers: false)

        #expect(available == .toGo)
    }

    @Test("The done section stays when the done groups have no keepers")
    func doneStaysWithoutKeepers() {
        let available = FolderSection.done.availableSection(hasDoneGroups: true, hasKeepers: false)

        #expect(available == .done)
    }

    @Test("The to-go section always shows")
    func toGoAlwaysShows() {
        let available = FolderSection.toGo.availableSection(hasDoneGroups: false, hasKeepers: false)

        #expect(available == .toGo)
    }
}
