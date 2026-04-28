import Foundation

/// The persisted state for a single folder, written to keeps.json alongside
/// the photos. Loaded on folder open and saved after every mark or pass change.
struct LibraryState: Codable {
    var marks: [UUID: FolderLibrary.Mark]
    var passes: [FolderLibrary.Pass]
    var currentPassIndex: Int
}
