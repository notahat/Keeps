/// A collapsed group as the sort screen draws it: its photos in pile order,
/// with the keepers on top, and how far narrowing it has got. Pure: worked
/// out from the group, the keepers, and whether the group is done, and does
/// no drawing.
struct Pile {
    /// The group's photos from the top of the pile down: the keepers first,
    /// then the rest, each in their original order.
    let photos: [PhotoItem]

    /// How many of the group's photos are keepers.
    let keeperCount: Int

    let isDone: Bool

    /// `group` is the photos' indices in `items`; `keepers` may include
    /// photos outside the group, which are ignored.
    init(group: Range<Int>, items: [PhotoItem], keepers: Set<Int>, isDone: Bool) {
        let kept = group.filter { keepers.contains($0) }
        let rest = group.filter { !keepers.contains($0) }
        photos = (kept + rest).map { items[$0] }
        keeperCount = kept.count
        self.isDone = isDone
    }

    /// Whether the photo at a layer, counting down from the top, is drawn
    /// faded: once the group is done, every photo that isn't a keeper is,
    /// so a group with nothing kept is faded throughout.
    func isFaded(layer: Int) -> Bool {
        isDone && layer >= keeperCount
    }
}
