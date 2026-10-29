import CoreGraphics
import Foundation
@testable import Keeps
import Testing

/// A minimal Codable state shape standing in for a real workflow's schema.
private struct StubState: Codable, Equatable {
    var names: [String]
}

/// A minimal observable model for exercising observation-triggered saves.
@Observable
private final class StubModel {
    var names: [String] = []
}

@MainActor
struct WorkflowPersistenceTests {
    @Test func roundTripsStateThroughSaveAndRestore() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let persistence = WorkflowPersistence<StubState>(folderURL: folder, workflowName: "stub-flow")

        try persistence.save(StubState(names: ["IMG_0001", "IMG_0002"]))
        let restored = persistence.restore()

        #expect(restored == StubState(names: ["IMG_0001", "IMG_0002"]))
    }

    @Test("Saving workflow state keeps the window frame already in the file")
    func saveKeepsOtherEntries() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = KeepsFile(folderURL: folder)
        try file.write(["windowFrame": CGRect(x: 1, y: 2, width: 3, height: 4)])
        let persistence = WorkflowPersistence<StubState>(folderURL: folder, workflowName: "stub-flow")

        try persistence.save(StubState(names: ["IMG_0001"]))

        #expect(file.read(CGRect.self, forKey: "windowFrame") == CGRect(x: 1, y: 2, width: 3, height: 4))
    }

    @Test func restoreReturnsNilWhenNoFileExists() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let persistence = WorkflowPersistence<StubState>(folderURL: folder, workflowName: "stub-flow")

        #expect(persistence.restore() == nil)
    }

    @Test func restoreReturnsNilWhenFileWasWrittenByADifferentWorkflow() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let writer = WorkflowPersistence<StubState>(folderURL: folder, workflowName: "old-flow")
        try writer.save(StubState(names: ["IMG_0001"]))

        let reader = WorkflowPersistence<StubState>(folderURL: folder, workflowName: "new-flow")

        #expect(reader.restore() == nil)
    }

    @Test func restoreReturnsNilWhenFileIsNotValidJson() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data("not json".utf8).write(to: folder.appendingPathComponent("keeps.json"))

        let persistence = WorkflowPersistence<StubState>(folderURL: folder, workflowName: "stub-flow")

        #expect(persistence.restore() == nil)
    }

    @Test func saveThrowsWhenFileCannotBeWritten() throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        // Pre-create a directory at the keeps.json path so the write fails.
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("keeps.json"),
            withIntermediateDirectories: false
        )
        let persistence = WorkflowPersistence<StubState>(folderURL: folder, workflowName: "stub-flow")

        #expect(throws: (any Error).self) {
            try persistence.save(StubState(names: []))
        }
    }

    @Test func observedChangeSavesAFreshSnapshot() async throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let persistence = WorkflowPersistence<StubState>(folderURL: folder, workflowName: "stub-flow")
        let model = StubModel()
        persistence.startObserving(
            read: { _ = model.names },
            snapshot: { StubState(names: model.names) },
            onSaveError: { _ in }
        )

        // The save runs on the next main-actor turn; yield until it has.
        model.names = ["IMG_0001"]
        for _ in 0 ..< 10 where persistence.restore() == nil {
            await Task.yield()
        }

        #expect(persistence.restore() == StubState(names: ["IMG_0001"]))
    }

    @Test func observedSaveFailureReportsTheError() async throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("keeps.json"),
            withIntermediateDirectories: false
        )
        let persistence = WorkflowPersistence<StubState>(folderURL: folder, workflowName: "stub-flow")
        let model = StubModel()
        let errorBox = ErrorBox()
        persistence.startObserving(
            read: { _ = model.names },
            snapshot: { StubState(names: model.names) },
            onSaveError: { errorBox.error = $0 }
        )

        model.names = ["IMG_0001"]
        for _ in 0 ..< 10 where errorBox.error == nil {
            await Task.yield()
        }

        #expect(errorBox.error != nil)
    }

    @Test func stopHaltsObservedSaves() async throws {
        let folder = try makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let persistence = WorkflowPersistence<StubState>(folderURL: folder, workflowName: "stub-flow")
        let model = StubModel()
        persistence.startObserving(
            read: { _ = model.names },
            snapshot: { StubState(names: model.names) },
            onSaveError: { _ in }
        )

        persistence.stop()
        model.names = ["IMG_0001"]
        for _ in 0 ..< 10 {
            await Task.yield()
        }

        #expect(persistence.restore() == nil)
    }
}

/// Captures an error reported through an escaping @MainActor callback.
@MainActor
private final class ErrorBox {
    var error: Error?
}
