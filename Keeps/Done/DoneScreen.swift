import SwiftUI

/// The done screen: the done groups, latest first, each drawn as a pile with
/// how many of its photos were kept. Clicking a group selects it, and
/// double-clicking it, or pressing Return with it selected, opens it on the
/// pick screen, where it can be changed or marked not done.
///
/// DoneScreen draws the groups and handles input. Grouping keeps track of
/// which groups are done and opens them, and Images draws the piles.
struct DoneScreen: View {
    let grouping: Grouping

    /// The group the user has selected on this screen.
    @State private var selectedGroup: Range<Int>?

    /// Whether the screen has keyboard focus, so that Return reaches it.
    @FocusState private var hasKeyboardFocus: Bool

    private static let cellSize = CGFloat(FramedPhoto.standardFrameLength)
    private static let spacing: CGFloat = 12

    /// Starts with the group last opened selected, if it's done, so coming
    /// back from the pick screen leaves the selection where it was. Opening
    /// a group selects its first photo (see Grouping.open(_:)), which is how
    /// the last opened group is found.
    init(grouping: Grouping) {
        self.grouping = grouping
        let lastOpened = grouping.selectedPhotoIndex
        _selectedGroup = State(initialValue: grouping.doneGroups.first { $0.lowerBound == lastOpened })
    }

    var body: some View {
        let groups = grouping.doneGroups
        if groups.isEmpty {
            Text("No groups are done yet.")
                .foregroundStyle(.secondary)
        } else {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    grid(of: groups)
                }
                .handlesKeys(hasKeyboardFocus: $hasKeyboardFocus, perform: handleKeyPress)
                .onAppear {
                    if let selectedGroup {
                        scrollProxy.scrollTo(selectedGroup.lowerBound, anchor: .center)
                    }
                }
            }
        }
    }

    /// The done groups as a grid of piles, as many columns as fit.
    private func grid(of groups: [Range<Int>]) -> some View {
        let columns = [GridItem(.adaptive(minimum: Self.cellSize, maximum: Self.cellSize), spacing: Self.spacing)]
        return LazyVGrid(columns: columns, spacing: Self.spacing) {
            ForEach(groups, id: \.lowerBound) { group in
                cell(for: group)
            }
        }
        .padding(Self.spacing)
    }

    /// One done group: its pile, how many were kept, and the selection
    /// highlight, with click handling.
    private func cell(for group: Range<Int>) -> some View {
        let pile = Pile(group: group, items: grouping.items, keepers: grouping.keepers)
        return PrintPile(photos: pile.photos, length: Self.cellSize, borderWidth: 7)
            .overlay(alignment: .bottom) {
                PileLabel(text: "\(grouping.keptCount(in: group)) of \(group.count) kept")
            }
            .selectionHighlight(isSelected: group == selectedGroup)
            .contentShape(Rectangle())
            // The single click is a simultaneous gesture rather than a
            // second onTapGesture. SwiftUI would hold back a plain single
            // tap until the double-click time had passed, to rule out a
            // double click, so selection would lag behind the click.
            .onTapGesture(count: 2) {
                grouping.open(group)
            }
            .simultaneousGesture(TapGesture().onEnded {
                selectedGroup = group
                hasKeyboardFocus = true
            })
    }

    /// Opens the selected group on the pick screen when Return is pressed.
    /// Returns whether the key press was handled.
    private func handleKeyPress(_ press: KeyPress) -> Bool {
        guard press.key == .return, let selectedGroup else { return false }
        grouping.open(selectedGroup)
        return true
    }
}
