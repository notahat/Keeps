import Foundation

/// The saved form of a folder's grouping, as written to keeps.json:
/// everything needed to pick up exactly where the user left off. Photos are
/// referred to by stem (filename without extension) rather than in-memory
/// UUIDs, so the saved grouping survives relaunches and folder moves.
///
/// keeps.json names its format in its "workflow" field. This format's name
/// is `originalFormatName`, which is what the app was called when the
/// format was first written.
///
/// Declared nonisolated because it is a plain value type with no actor
/// affinity; otherwise the target's main-actor default would isolate its
/// Equatable conformance.
nonisolated struct SavedGrouping: Codable, Equatable {
    /// This format's name, as written in keeps.json's "workflow" field.
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

        /// Read a position written as the string "end" or as
        /// {"before": stem}, and throw for any other string.
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

        /// Write the position as {"before": stem} or the string "end".
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
        /// The stem of the photo whose row is at the top of the view.
        var stem: String

        /// How far into that row the view has scrolled, in points.
        var offsetFromRowTop: Double
    }

    /// The boundaries, in folder order.
    var boundaries: [Position]

    /// The point up to which groups are collapsed, or nil for none.
    var collapsedUpTo: Position?

    /// The stem of the selected photo, or nil for no selection.
    var selectedStem: String?

    /// The sort screen's scroll position, or nil if it has none.
    var scrollAnchor: ScrollAnchor?

    /// The photos picked to keep, in folder order. Optional, like
    /// `doneGroupStartStems`, because files saved before picking existed
    /// don't have it, and so that a folder with nothing picked saves no
    /// entry.
    var keeperStems: [String]? = nil

    /// The groups marked done, each by the stem of its first photo, in
    /// folder order.
    var doneGroupStartStems: [String]? = nil
}
