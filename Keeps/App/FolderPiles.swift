import SwiftUI

/// The parts of a folder the piles switch between: the photos still to go,
/// on the sort screen, and the done groups.
enum FolderSection {
    case toGo, done

    /// The section's name, as the window title shows it.
    var title: String {
        switch self {
        case .toGo: "To go"
        case .done: "Done groups"
        }
    }
}

/// The sidebar of piles beside a folder's screen, showing where every photo
/// is: kept, still to go, or set aside, so their counts add up to the
/// folder. They also switch sections: clicking the to-go pile shows the sort
/// screen, and clicking the set-aside pile shows the done groups. The pile
/// for the section showing sits on a highlight, like a selected sidebar
/// item. The keepers pile isn't a section: it's dragged out of the app
/// instead, as the keepers' files, for Lightroom or Finder.
///
/// Draws and takes clicks only; FolderView decides where the piles go, shows
/// them only once a group is done, and decides what each section shows.
struct FolderPiles: View {
    let grouping: Grouping
    @Binding var section: FolderSection

    private static let length: CGFloat = 160
    private static let spacing: CGFloat = 12

    /// Room around each pile, inside its highlight.
    private static let highlightPadding: CGFloat = 8

    var body: some View {
        // Each is worked out once per render, since each walks the folder.
        let toGo = grouping.photosToGo
        let keepers = grouping.keepersOfDoneGroups
        let setAside = grouping.setAsideFromDoneGroups
        return VStack(spacing: Self.spacing) {
            // The keepers and to-go piles appear only while they have
            // something to show. The set-aside pile always shows, even if
            // nothing was set aside, since it's the way to the done groups.
            if !keepers.isEmpty {
                let keepersLabel = keepers.count == 1 ? "1 keeper" : "\(keepers.count) keepers"
                pile(of: keepers, label: keepersLabel, color: KeeperBadge.color)
                    .overlay {
                        PhotoDragSource(photos: keepers.map { grouping.items[$0] })
                    }
                    .help("Drag the keepers into Lightroom or a Finder folder")
                    .padding(Self.highlightPadding)
            }
            if !toGo.isEmpty {
                pile(of: toGo, label: "\(toGo.count) to go")
                    .sectionItem(.toGo, selection: $section, padding: Self.highlightPadding)
            }
            pile(of: setAside, label: "\(setAside.count) set aside")
                .sectionItem(.done, selection: $section, padding: Self.highlightPadding)
        }
    }

    /// One labelled pile of some of the folder's photos. Its blank paper is
    /// the typical shape, since its photos may come from many groups.
    private func pile(of photoIndices: [Int], label: String, color: Color? = nil) -> some View {
        PrintPile(
            photos: photoIndices.map { grouping.items[$0] },
            length: Self.length,
            aspectRatio: ThumbnailImage.typicalAspectRatio
        )
        .overlay(alignment: .bottom) {
            PileLabel(text: label, color: color)
        }
    }
}

private extension View {
    /// Makes a pile choose a section when clicked, sitting on a highlight
    /// while that section is showing.
    func sectionItem(_ itemSection: FolderSection, selection: Binding<FolderSection>, padding: CGFloat) -> some View {
        self.padding(padding)
            .background {
                if selection.wrappedValue == itemSection {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.25))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture { selection.wrappedValue = itemSection }
    }
}
