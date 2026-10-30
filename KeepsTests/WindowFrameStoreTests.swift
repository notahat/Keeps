import CoreGraphics
import Foundation
@testable import Keeps
import Testing

struct WindowFrameStoreTests {
    @Test("A saved frame is read back")
    func roundTripsAFrame() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let frame = CGRect(x: 10, y: 20, width: 900, height: 600)

        try WindowFrameStore.save(frame, in: folder)

        #expect(WindowFrameStore.savedFrame(in: folder) == frame)
    }

    @Test("A folder with no saved frame gives nothing")
    func noSavedFrame() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(WindowFrameStore.savedFrame(in: folder) == nil)
    }

    @Test("Saving a frame keeps the workflow's state in the file")
    func keepsWorkflowState() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = KeepsFile(folderURL: folder)
        try file.write(["workflow": "group-cull"])

        try WindowFrameStore.save(CGRect(x: 0, y: 0, width: 800, height: 500), in: folder)

        #expect(file.read(String.self, forKey: "workflow") == "group-cull")
    }
}
