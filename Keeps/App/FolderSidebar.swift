import SwiftUI

/// The sidebar beside a folder's screen: a pile each for the photos kept,
/// still to go, and set aside, showing where every photo is, so their
/// counts add up to the folder. Clicking a pile also selects a section: the
/// keepers pile shows the keepers screen, the to-go pile the sort screen,
/// and the set-aside pile the done groups. The pile for the section showing
/// sits on a highlight, like a selected sidebar item. The user can also
/// drag the keepers pile out of the app, as the keepers' files, into
/// Lightroom or Finder.
///
/// It only draws the piles and takes clicks. FolderView places the sidebar,
/// shows it only once a group is done, and shows each section's screen.
struct FolderSidebar: View {
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
                // The drag source takes the clicks as well as the drags, so
                // it selects the section itself.
                pile(of: keepers, label: keepersLabel, color: KeeperBadge.color)
                    .sectionHighlight(.keepers, selection: section, padding: Self.highlightPadding)
                    .overlay {
                        PhotoDragSource(photos: keepers.map { grouping.photos[$0] }) {
                            section = .keepers
                        }
                    }
                    .help("Click to see the keepers, or drag them into Lightroom or a Finder folder")
            }
            if !toGo.isEmpty {
                pile(of: toGo, label: "\(toGo.count) to go")
                    .sectionItem(.toGo, selection: $section, padding: Self.highlightPadding)
            }
            pile(of: setAside, label: "\(setAside.count) set aside")
                .sectionItem(.done, selection: $section, padding: Self.highlightPadding)
        }
    }

    /// One labelled pile of some of the folder's photos. Its blank prints
    /// are the typical shape, since its photos may come from many groups.
    private func pile(of photoIndices: [Int], label: String, color: Color? = nil) -> some View {
        PrintPile(
            photos: photoIndices.map { grouping.photos[$0] },
            length: Self.length,
            aspectRatio: FramedPhoto.typicalAspectRatio
        )
        .overlay(alignment: .bottom) {
            PileLabel(text: label, color: color)
        }
    }
}

private extension View {
    /// Makes a pile select its section when clicked, sitting on a highlight
    /// while that section is showing.
    func sectionItem(_ itemSection: FolderSection, selection: Binding<FolderSection>, padding: CGFloat) -> some View {
        sectionHighlight(itemSection, selection: selection.wrappedValue, padding: padding)
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture { selection.wrappedValue = itemSection }
    }

    /// Pads a pile and sits it on a highlight while its section is showing.
    func sectionHighlight(_ itemSection: FolderSection, selection: FolderSection, padding: CGFloat) -> some View {
        self.padding(padding)
            .background {
                if selection == itemSection {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.25))
                }
            }
    }
}
