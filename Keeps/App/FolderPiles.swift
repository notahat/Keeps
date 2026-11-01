import SwiftUI

/// The parts of a folder the piles switch between: the photos still to go,
/// on the sort screen, and the done groups.
enum FolderSection {
    case toGo, done
}

/// The piles beside a folder's screen, showing where every photo is: still
/// to go, kept, or set aside, so their counts add up to the folder. They
/// also switch sections: clicking the to-go pile shows the sort screen, and
/// clicking the set-aside pile shows the done groups. The pile for the
/// section showing has its label highlighted. The keepers pile only shows,
/// for now.
///
/// Draws and takes clicks only; FolderView decides where the piles go and
/// what each section shows.
struct FolderPiles: View {
    let grouping: Grouping
    @Binding var section: FolderSection

    private static let length: CGFloat = 160
    private static let spacing: CGFloat = 24

    /// The shape of most camera sensors, for the blank paper, since a pile's
    /// photos may come from many groups.
    private static let paperAspectRatio: CGFloat = 1.5

    var body: some View {
        // Each is worked out once per render, since each walks the folder.
        let toGo = grouping.photosToGo
        let keepers = grouping.keepersOfDoneGroups
        let setAside = grouping.setAsideFromDoneGroups
        return VStack(spacing: Self.spacing) {
            pile(of: toGo, label: "\(toGo.count) to go", color: color(for: .toGo))
                .onTapGesture { section = .toGo }
            // Green, to match the keeper badge on the pick screen.
            pile(of: keepers, label: keepers.count == 1 ? "1 keeper" : "\(keepers.count) keepers", color: .green)
            pile(of: setAside, label: "\(setAside.count) set aside", color: color(for: .done))
                .onTapGesture { section = .done }
        }
    }

    /// The label colour for a section's pile: the accent colour while that
    /// section is showing, otherwise none.
    private func color(for pileSection: FolderSection) -> Color? {
        pileSection == section ? .accentColor : nil
    }

    /// One labelled pile of some of the folder's photos.
    private func pile(of photoIndices: [Int], label: String, color: Color?) -> some View {
        PrintPile(
            photos: photoIndices.map { grouping.items[$0] },
            length: Self.length,
            aspectRatio: Self.paperAspectRatio
        )
        .overlay(alignment: .bottom) {
            PileLabel(text: label, color: color)
        }
        .contentShape(Rectangle())
    }
}
