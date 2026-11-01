import SwiftUI

/// Where the done groups' photos go once they've left the sort screen's
/// grid: a pile of the keepers above a pile of the photos set aside, each a
/// PrintPile labelled with its count. They grow as done groups leave the
/// grid. Draws only; SortScreen decides where they go and when they show.
struct DonePiles: View {
    /// The kept photos, from the top of the pile down.
    let keepers: [PhotoItem]

    /// The photos set aside, from the top of the pile down.
    let setAside: [PhotoItem]

    private static let length: CGFloat = 160
    private static let spacing: CGFloat = 24

    /// The shape of most camera sensors, for the blank paper shown while
    /// the prints load, since the photos may come from many groups.
    private static let paperAspectRatio: CGFloat = 1.5

    var body: some View {
        VStack(spacing: Self.spacing) {
            pile(of: keepers, label: keepers.count == 1 ? "1 keeper" : "\(keepers.count) keepers")
            pile(of: setAside, label: "\(setAside.count) set aside")
        }
    }

    /// One labelled pile.
    private func pile(of photos: [PhotoItem], label: String) -> some View {
        PrintPile(photos: photos, length: Self.length, aspectRatio: Self.paperAspectRatio)
            .overlay(alignment: .bottom) {
                PileLabel(text: label)
            }
    }
}
