/// A group's photos in the order a pile of them is drawn: the
/// keepers already picked on top, then the rest. Pure: worked out from the
/// group and the keepers, and does no drawing.
struct Pile {
    /// The group's photos from the top of the pile down: the keepers first,
    /// then the rest, each in their original order.
    let photos: [PhotoItem]

    /// Orders a group's photos for its pile. `group` is the photos' indices
    /// in `items`; `keepers` may include photos outside the group, which
    /// are ignored.
    init(group: Range<Int>, items: [PhotoItem], keepers: Set<Int>) {
        let kept = group.filter { keepers.contains($0) }
        let rest = group.filter { !keepers.contains($0) }
        photos = (kept + rest).map { items[$0] }
    }
}
