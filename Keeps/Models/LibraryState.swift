import Foundation

/// The persisted state for a single folder, written to keeps.json alongside
/// the photos. Loaded on folder open and saved after every mark or pass change.
/// Uses photo stems (filename without extension) as keys so state survives
/// folder moves.
struct LibraryState: Codable {
    struct Pass: Codable {
        var stems: [String]
        var committedStats: FolderLibrary.PassStats?
    }

    var marks: [String: FolderLibrary.Mark]
    var passes: [Pass]
}
