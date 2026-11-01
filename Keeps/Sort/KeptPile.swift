import SwiftUI

/// The sort screen's pile of everything kept so far: the keepers of the done
/// groups as a PrintPile, labelled with how many were kept from how many
/// groups. It grows as done groups leave the grid. Draws only; SortScreen
/// decides where it goes and when it shows.
struct KeptPile: View {
    /// The kept photos, from the top of the pile down.
    let photos: [PhotoItem]

    let doneGroupCount: Int

    private static let length: CGFloat = 160

    /// The shape of most camera sensors, for the blank paper shown while
    /// the prints load, since the photos may come from many groups.
    private static let paperAspectRatio: CGFloat = 1.5

    var body: some View {
        PrintPile(photos: photos, length: Self.length, aspectRatio: Self.paperAspectRatio)
            .overlay(alignment: .bottom) {
                PileLabel(text: label)
            }
    }

    private var label: String {
        let groups = doneGroupCount == 1 ? "group" : "groups"
        return "\(photos.count) kept from \(doneGroupCount) \(groups)"
    }
}
