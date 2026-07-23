import Foundation

/// Moves photos into Picked/, Rejected/, and Undecided/ subdirectories based
/// on their cumulative marks. One-shot destructive operation used as the final
/// step after culling. Does not handle any workflow or UI state.
enum PhotoSorter {
    struct Move {
        let source: URL
        let destination: URL
    }

    /// Computes the file moves needed to sort photos into subdirectories.
    static func plannedMoves(
        folderURL: URL,
        sortPlan: [MarkStore.Mark?: [PhotoItem]]
    ) -> [Move] {
        sortPlan.flatMap { mark, items in
            let subdirectory = folderURL.appendingPathComponent(directoryName(for: mark))
            return items.flatMap { item in
                movesForItem(item, destination: subdirectory)
            }
        }
    }

    /// Creates subdirectories and executes all file moves. Throws on first
    /// failure. Call deleteKeepsJSON separately after this succeeds.
    static func execute(folderURL: URL, moves: [Move]) throws {
        let fileManager = FileManager.default
        let subdirectories = [
            folderURL.appendingPathComponent("Picked"),
            folderURL.appendingPathComponent("Rejected"),
            folderURL.appendingPathComponent("Undecided"),
        ]
        for directory in subdirectories {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        for move in moves {
            try fileManager.moveItem(at: move.source, to: move.destination)
        }
    }

    /// Removes keeps.json from the folder.
    static func deleteKeepsJSON(in folderURL: URL) throws {
        let fileURL = folderURL.appendingPathComponent("keeps.json")
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    private static func directoryName(for mark: MarkStore.Mark?) -> String {
        switch mark {
        case .pick: "Picked"
        case .reject: "Rejected"
        case nil: "Undecided"
        }
    }

    private static func movesForItem(_ item: PhotoItem, destination: URL) -> [Move] {
        var moves: [Move] = []
        if let rawURL = item.rawURL {
            let dest = destination.appendingPathComponent(rawURL.lastPathComponent)
            moves.append(Move(source: rawURL, destination: dest))
        }
        if let jpegURL = item.jpegURL {
            let dest = destination.appendingPathComponent(jpegURL.lastPathComponent)
            moves.append(Move(source: jpegURL, destination: dest))
        }
        return moves
    }
}
