import Foundation
@testable import Keeps
import Testing

struct OpenFolderListTests {
    /// A list backed by a fresh, empty defaults domain, so tests don't touch
    /// the app's real preferences or each other.
    private func makeList() -> OpenFolderList {
        let suiteName = "OpenFolderListTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return OpenFolderList(defaults: defaults)
    }

    private func makeReference(_ name: String) -> FolderReference {
        FolderReference(url: URL(fileURLWithPath: "/tmp/\(name)", isDirectory: true), bookmark: Data(name.utf8))
    }

    @Test("Nothing is remembered to begin with")
    func startsEmpty() {
        #expect(makeList().folders.isEmpty)
    }

    @Test("An opened folder is remembered")
    func remembersOpenedFolder() {
        let list = makeList()

        list.add(makeReference("a"))

        #expect(list.folders == [makeReference("a")])
    }

    @Test("Opening a folder twice remembers it once")
    func noDuplicates() {
        let list = makeList()

        list.add(makeReference("a"))
        list.add(makeReference("a"))

        #expect(list.folders.count == 1)
    }

    @Test("A closed folder is forgotten")
    func forgetsClosedFolder() {
        let list = makeList()
        list.add(makeReference("a"))
        list.add(makeReference("b"))

        list.remove(makeReference("a"))

        #expect(list.folders == [makeReference("b")])
    }

    @Test("A refreshed folder takes the old one's place in the list")
    func replacesFolderInPlace() {
        let list = makeList()
        list.add(makeReference("a"))
        list.add(makeReference("b"))
        list.add(makeReference("c"))

        list.replace(makeReference("b"), with: makeReference("moved"))

        #expect(list.folders == [makeReference("a"), makeReference("moved"), makeReference("c")])
    }

    @Test("Replacing a folder that isn't remembered leaves the list alone")
    func replaceIgnoresUnknownFolder() {
        let list = makeList()
        list.add(makeReference("a"))

        list.replace(makeReference("b"), with: makeReference("moved"))

        #expect(list.folders == [makeReference("a")])
    }

    @Test("The list survives the app restarting")
    func persistsAcrossInstances() throws {
        let suiteName = "OpenFolderListTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        OpenFolderList(defaults: defaults).add(makeReference("a"))

        let reloaded = OpenFolderList(defaults: defaults)

        #expect(reloaded.folders == [makeReference("a")])
        #expect(reloaded.folders.first?.bookmark == makeReference("a").bookmark)
        defaults.removePersistentDomain(forName: suiteName)
    }
}
