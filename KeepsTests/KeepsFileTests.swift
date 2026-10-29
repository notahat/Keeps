import CoreGraphics
import Foundation
@testable import Keeps
import Testing

struct KeepsFileTests {
    @Test("An entry written to the file can be read back")
    func roundTripsAnEntry() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = KeepsFile(folderURL: folder)

        try file.write(["windowFrame": CGRect(x: 10, y: 20, width: 900, height: 600)])

        #expect(file.read(CGRect.self, forKey: "windowFrame") == CGRect(x: 10, y: 20, width: 900, height: 600))
    }

    @Test("Writing one entry keeps the others already in the file")
    func keepsOtherEntries() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = KeepsFile(folderURL: folder)
        try file.write(["workflow": "group-cull"])

        try file.write(["windowFrame": CGRect(x: 0, y: 0, width: 800, height: 500)])

        #expect(file.read(String.self, forKey: "workflow") == "group-cull")
    }

    @Test("Reading an entry that isn't in the file gives nothing")
    func missingEntryIsNil() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = KeepsFile(folderURL: folder)
        try file.write(["workflow": "group-cull"])

        #expect(file.read(CGRect.self, forKey: "windowFrame") == nil)
    }

    @Test("Reading from a folder with no file gives nothing")
    func missingFileIsNil() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(KeepsFile(folderURL: folder).read(String.self, forKey: "workflow") == nil)
    }
}
