import Foundation
@testable import Keeps
import Testing

struct PhotoSorterTests {
    @Test func pickedPhotoMovesToPickedDirectory() throws {
        let folder = try makeTemporaryFolder()
        let item = PhotoItem(
            id: UUID(), stem: "IMG_001",
            rawURL: folder.appendingPathComponent("IMG_001.CR3"),
            jpegURL: nil, capturedAt: Date()
        )
        let sortPlan: [PassStore.Mark?: [PhotoItem]] = [.pick: [item]]

        let moves = PhotoSorter.plannedMoves(folderURL: folder, sortPlan: sortPlan)

        #expect(moves.count == 1)
        #expect(moves[0].source == item.rawURL)
        #expect(moves[0].destination == folder.appendingPathComponent("Picked/IMG_001.CR3"))
    }

    @Test func rejectedPhotoMovesToRejectedDirectory() throws {
        let folder = try makeTemporaryFolder()
        let item = PhotoItem(
            id: UUID(), stem: "IMG_001",
            rawURL: nil,
            jpegURL: folder.appendingPathComponent("IMG_001.jpg"),
            capturedAt: Date()
        )
        let sortPlan: [PassStore.Mark?: [PhotoItem]] = [.reject: [item]]

        let moves = PhotoSorter.plannedMoves(folderURL: folder, sortPlan: sortPlan)

        #expect(moves.count == 1)
        #expect(moves[0].destination == folder.appendingPathComponent("Rejected/IMG_001.jpg"))
    }

    @Test func unmarkedPhotoMovesToUndecidedDirectory() throws {
        let folder = try makeTemporaryFolder()
        let item = PhotoItem(
            id: UUID(), stem: "IMG_001",
            rawURL: folder.appendingPathComponent("IMG_001.CR3"),
            jpegURL: nil, capturedAt: Date()
        )
        let sortPlan: [PassStore.Mark?: [PhotoItem]] = [nil: [item]]

        let moves = PhotoSorter.plannedMoves(folderURL: folder, sortPlan: sortPlan)

        #expect(moves.count == 1)
        #expect(moves[0].destination == folder.appendingPathComponent("Undecided/IMG_001.CR3"))
    }

    @Test func rawAndJpegPairBothMoveToSameDirectory() throws {
        let folder = try makeTemporaryFolder()
        let item = PhotoItem(
            id: UUID(), stem: "IMG_001",
            rawURL: folder.appendingPathComponent("IMG_001.CR3"),
            jpegURL: folder.appendingPathComponent("IMG_001.jpg"),
            capturedAt: Date()
        )
        let sortPlan: [PassStore.Mark?: [PhotoItem]] = [.pick: [item]]

        let moves = PhotoSorter.plannedMoves(folderURL: folder, sortPlan: sortPlan)

        #expect(moves.count == 2)
        let destinations = Set(moves.map(\.destination))
        #expect(destinations.contains(folder.appendingPathComponent("Picked/IMG_001.CR3")))
        #expect(destinations.contains(folder.appendingPathComponent("Picked/IMG_001.jpg")))
    }

    @Test func executeMovesFilesIntoSubdirectories() throws {
        let folder = try makeTemporaryFolder()
        try makeFile(named: "IMG_001.CR3", in: folder)
        try makeFile(named: "IMG_002.jpg", in: folder)

        let moves = [
            PhotoSorter.Move(
                source: folder.appendingPathComponent("IMG_001.CR3"),
                destination: folder.appendingPathComponent("Picked/IMG_001.CR3")
            ),
            PhotoSorter.Move(
                source: folder.appendingPathComponent("IMG_002.jpg"),
                destination: folder.appendingPathComponent("Rejected/IMG_002.jpg")
            ),
        ]

        try PhotoSorter.execute(folderURL: folder, moves: moves)

        let fileManager = FileManager.default
        #expect(fileManager.fileExists(atPath: folder.appendingPathComponent("Picked/IMG_001.CR3").path))
        #expect(fileManager.fileExists(atPath: folder.appendingPathComponent("Rejected/IMG_002.jpg").path))
        #expect(!fileManager.fileExists(atPath: folder.appendingPathComponent("IMG_001.CR3").path))
        #expect(!fileManager.fileExists(atPath: folder.appendingPathComponent("IMG_002.jpg").path))
    }

    @Test func executeCreatesAllThreeSubdirectories() throws {
        let folder = try makeTemporaryFolder()

        try PhotoSorter.execute(folderURL: folder, moves: [])

        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        #expect(fileManager.fileExists(atPath: folder.appendingPathComponent("Picked").path, isDirectory: &isDirectory) && isDirectory.boolValue)
        #expect(fileManager.fileExists(atPath: folder.appendingPathComponent("Rejected").path, isDirectory: &isDirectory) && isDirectory.boolValue)
        #expect(fileManager.fileExists(atPath: folder.appendingPathComponent("Undecided").path, isDirectory: &isDirectory) && isDirectory.boolValue)
    }

    @Test func deleteKeepsJSONRemovesFile() throws {
        let folder = try makeTemporaryFolder()
        let data = try #require("{}".data(using: .utf8))
        try data.write(to: folder.appendingPathComponent("keeps.json"))

        try PhotoSorter.deleteKeepsJSON(in: folder)

        #expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("keeps.json").path))
    }

    @Test func deleteKeepsJSONDoesNothingWhenFileIsMissing() throws {
        let folder = try makeTemporaryFolder()

        try PhotoSorter.deleteKeepsJSON(in: folder)
    }
}
