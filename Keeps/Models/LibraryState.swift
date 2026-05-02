import Foundation

/// The persisted state for a single folder, written to keeps.json alongside
/// the photos. Loaded on folder open and saved after every mark, pass, or group
/// change. Uses photo stems (filename without extension) as keys so state
/// survives folder moves.
struct LibraryState: Codable {
    struct Pass: Codable {
        var picks: [String]
        var rejects: [String]
    }

    struct PhotoGroup: Codable {
        var id: UUID
        var colorIndex: Int
        var stems: [String]
    }

    var passes: [Pass]
    var groups: [PhotoGroup]

    init(passes: [Pass], groups: [PhotoGroup] = []) {
        self.passes = passes
        self.groups = groups
    }

    /// Custom decoder so that old keeps.json files without a "groups" key
    /// decode successfully, producing an empty groups array.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        passes = try container.decode([Pass].self, forKey: .passes)
        groups = (try? container.decode([PhotoGroup].self, forKey: .groups)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case passes, groups
    }
}
