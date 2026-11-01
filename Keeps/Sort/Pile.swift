/// A collapsed group as the sort screen draws it: its photos in pile order,
/// with any keepers already picked on top. Pure: worked out from the group
/// and the keepers, and does no drawing. Done groups have no cell, so are
/// never drawn as one of these.
struct Pile {
    /// The group's photos from the top of the pile down: the keepers first,
    /// then the rest, each in their original order.
    let photos: [PhotoItem]

    /// `group` is the photos' indices in `items`; `keepers` may include
    /// photos outside the group, which are ignored.
    init(group: Range<Int>, items: [PhotoItem], keepers: Set<Int>) {
        let kept = group.filter { keepers.contains($0) }
        let rest = group.filter { !keepers.contains($0) }
        photos = (kept + rest).map { items[$0] }
    }
}
