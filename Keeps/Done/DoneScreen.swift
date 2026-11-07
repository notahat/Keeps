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

    /// The width and height of each pile in points.
    private static let pileLength = CGFloat(FramedPhoto.standardFrameLength)

    /// The space in points between piles and around the grid.
    private static let spacing = FramedPhoto.gridSpacing

    /// Start with the group last opened selected, if that group is done, so
    /// coming back from the pick screen leaves the selection where it was.
    init(grouping: Grouping) {
        self.grouping = grouping
        let lastOpened = grouping.lastOpenedGroup
        _selectedGroup = State(initialValue: grouping.doneGroups.first { $0 == lastOpened })
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

    /// Build the done groups as a grid of piles, as many columns as fit.
    private func grid(of groups: [Range<Int>]) -> some View {
        let columns = [GridItem(.adaptive(minimum: Self.pileLength, maximum: Self.pileLength), spacing: Self.spacing)]
        return LazyVGrid(columns: columns, spacing: Self.spacing) {
            ForEach(groups, id: \.lowerBound) { group in
                pile(of: group)
            }
        }
        .padding(Self.spacing)
    }

    /// Build one done group's pile, with how many of its photos were kept,
    /// the selection highlight, and click handling.
    private func pile(of group: Range<Int>) -> some View {
        let pileOrder = Pile(group: group, folderPhotos: grouping.photos, keepers: grouping.keepers)
        return PrintPile(photos: pileOrder.photos, length: Self.pileLength, borderWidth: PrintPile.standardFrameBorderWidth)
            .overlay(alignment: .bottom) {
                PileLabel(text: "\(grouping.keptCount(in: group)) of \(group.count) kept")
            }
            .selectionHighlight(isSelected: group == selectedGroup)
            .contentShape(Rectangle())
            .onClick { _ in
                selectedGroup = group
                hasKeyboardFocus = true
            } onDoubleClick: { _ in
                grouping.open(group)
            }
    }

    /// Open the selected group on the pick screen when Return is pressed.
    /// Return whether the key press was handled.
    private func handleKeyPress(_ press: KeyPress) -> Bool {
        guard press.key == .return, let selectedGroup else { return false }
        grouping.open(selectedGroup)
        return true
    }
}
