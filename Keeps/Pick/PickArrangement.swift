/// Which of the open group's photos the pick screen lays out as tiles, and
/// which sit on the pile: every photo is a tile until the group is done, and
/// then only its keepers are, with the rest on the pile. Photos are named by
/// their place in the group. Pure; where the tiles and pile go is TileLayout's
/// and PickScreen's job.
nonisolated struct PickArrangement {
    /// The photos shown as tiles, in group order.
    let tilePlaces: [Int]

    /// The photos on the pile, in group order.
    let pilePlaces: [Int]

    init(photoCount: Int, keeperPlaces: Set<Int>, isDone: Bool) {
        let places = Array(0 ..< photoCount)
        guard isDone else {
            tilePlaces = places
            pilePlaces = []
            return
        }
        tilePlaces = places.filter { keeperPlaces.contains($0) }
        pilePlaces = places.filter { !keeperPlaces.contains($0) }
    }

    /// The tile to focus in place of the photo at a place: that photo's own
    /// tile, or the nearest tile before it, or the first tile. Nil when there
    /// are no tiles.
    func tileIndex(nearestPlace place: Int) -> Int? {
        guard !tilePlaces.isEmpty else { return nil }
        return tilePlaces.lastIndex { $0 <= place } ?? 0
    }
}
