/// Which of the open group's photos the pick screen lays out as tiles, and
/// which sit on the pile: every photo is a tile until the group is done, and
/// then only its keepers are, with the rest on the pile. Photos are named by
/// their index in the folder, as everywhere else. Pure; where the tiles and
/// pile go is TileLayout's and PickScreen's job.
nonisolated struct PickArrangement {
    /// The photos shown as tiles, in folder order.
    let tilePhotos: [Int]

    /// The photos on the pile, in folder order.
    let pilePhotos: [Int]

    /// `keepers` may include photos outside the group, which are ignored.
    init(group: Range<Int>, keepers: Set<Int>, isDone: Bool) {
        let photos = Array(group)
        guard isDone else {
            tilePhotos = photos
            pilePhotos = []
            return
        }
        tilePhotos = photos.filter { keepers.contains($0) }
        pilePhotos = photos.filter { !keepers.contains($0) }
    }

    /// The tile to focus in place of a photo: that photo's own tile, or the
    /// nearest tile before it, or the first tile. Nil when there are no
    /// tiles.
    func tileIndex(nearestPhoto photoIndex: Int) -> Int? {
        guard !tilePhotos.isEmpty else { return nil }
        return tilePhotos.lastIndex { $0 <= photoIndex } ?? 0
    }
}
