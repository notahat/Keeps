import Foundation

/// Converts between where photos sit in the folder, which is how Grouping
/// refers to them, and their stems, which is how SavedGrouping does. Pure:
/// built once from the folder's photos, which don't change while it's open.
struct PhotoStems {
    private let items: [PhotoItem]
    private let indexByStem: [String: Int]
    private let indexByID: [UUID: Int]

    init(items: [PhotoItem]) {
        self.items = items
        indexByStem = Dictionary(uniqueKeysWithValues: items.enumerated().map { ($1.stem, $0) })
        indexByID = Dictionary(uniqueKeysWithValues: items.enumerated().map { ($1.id, $0) })
    }

    /// The photo with a stem, or nil if it's no longer in the folder.
    func photoIndex(ofStem stem: String) -> Int? {
        indexByStem[stem]
    }

    /// The stem of the photo with an in-memory id, or nil if there's none.
    func stem(ofItemID id: UUID) -> String? {
        indexByID[id].map { items[$0].stem }
    }

    /// The saved form of the point just before a photo, or after the last
    /// one when the index is the photo count.
    func position(beforePhoto photoIndex: Int) -> SavedGrouping.Position {
        photoIndex < items.count ? .beforePhoto(items[photoIndex].stem) : .end
    }

    /// The photo index a saved position refers to, or nil if its photo is no
    /// longer in the folder.
    func photoIndex(at position: SavedGrouping.Position) -> Int? {
        switch position {
        case let .beforePhoto(stem): indexByStem[stem]
        case .end: items.count
        }
    }

    /// The stems of a set of photos in folder order, or nil when there are
    /// none, so that saving nothing writes no entry.
    func stems(ofPhotos photoIndices: Set<Int>) -> [String]? {
        photoIndices.isEmpty ? nil : photoIndices.sorted().map { items[$0].stem }
    }

    /// The photos with the given stems, leaving out any no longer in the
    /// folder. A missing entry is no photos.
    func photoIndices(ofStems stems: [String]?) -> Set<Int> {
        Set((stems ?? []).compactMap { indexByStem[$0] })
    }
}
