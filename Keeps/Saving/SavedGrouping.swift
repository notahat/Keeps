import Foundation

/// The saved form of a folder's grouping, as written to keeps.json:
/// everything needed to pick up exactly where the user left off. Photos are
/// referred to by stem (filename without extension) rather than in-memory
/// UUIDs so it survives relaunches and folder moves.
///
/// keeps.json names its format in its "workflow" field. This format is
/// named `originalFormatName`, for the name the app had when it was first
/// saved.
///
/// Declared nonisolated because it is a plain value type with no actor
/// affinity; otherwise the target's main-actor default would isolate its
/// Equatable conformance.
nonisolated struct SavedGrouping: Codable, Equatable {
    static let originalFormatName = "group-cull"

    /// A point between photos: just before a named photo, or after the last
    /// one. Written as {"before": stem} or the string "end", so keeps.json
    /// stays readable.
    enum Position: Codable, Equatable {
        case beforePhoto(String)
        case end

        private enum CodingKeys: String, CodingKey {
            case before
        }

        private static let endMarker = "end"

        init(from decoder: Decoder) throws {
            if let single = try? decoder.singleValueContainer(),
               let marker = try? single.decode(String.self)
            {
                guard marker == Self.endMarker else {
                    throw DecodingError.dataCorruptedError(
                        in: single, debugDescription: "Unknown position \"\(marker)\""
                    )
                }
                self = .end
                return
            }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self = try .beforePhoto(container.decode(String.self, forKey: .before))
        }

        func encode(to encoder: Encoder) throws {
            switch self {
            case let .beforePhoto(stem):
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(stem, forKey: .before)
            case .end:
                var container = encoder.singleValueContainer()
                try container.encode(Self.endMarker)
            }
        }
    }

    /// The scroll position: the photo whose row is at the top of the view,
    /// and how far into that row the view has scrolled.
    struct ScrollAnchor: Codable, Equatable {
        var stem: String
        var offsetFromRowTop: Double
    }

    var boundaries: [Position]
    var collapsedUpTo: Position?
    var selectedStem: String?
    var scrollAnchor: ScrollAnchor?

    /// The photos picked to keep, in folder order. Optional, like
    /// `doneGroupStartStems`, because files saved before narrowing existed
    /// don't have it, and so that a folder with nothing picked saves no
    /// entry.
    var keeperStems: [String]? = nil

    /// The groups marked done, each by the stem of its first photo, in
    /// folder order.
    var doneGroupStartStems: [String]? = nil
}
