import SwiftUI

/// The done screen: the done groups, latest first, each drawn as a pile with
/// how many of its photos were kept. Clicking a group selects it, and
/// double-clicking it, or pressing Return with it selected, opens it on the
/// pick screen, where it can be changed or marked not done.
///
/// Draws the groups and handles input. Which groups are done, and opening
/// them, are Grouping's; how a pile is drawn is Images'.
struct DoneScreen: View {
    let grouping: Grouping

    /// The selected group. Starts on the group last opened, so coming back
    /// from the pick screen keeps your place.
    @State private var selectedGroup: Range<Int>?

    @FocusState private var isFocused: Bool

    private static let cellSize = CGFloat(ThumbnailImage.displaySize)
    private static let spacing: CGFloat = 12

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
                .handlesKeys(isFocused: $isFocused, perform: handleKeyPress)
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
            // The single click is simultaneous rather than a second tap
            // gesture, which would wait out the double-click time and make
            // selection lag.
            .onTapGesture(count: 2) {
                grouping.open(group)
            }
            .simultaneousGesture(TapGesture().onEnded {
                selectedGroup = group
                isFocused = true
            })
    }

    /// Return opens the selected group on the pick screen.
    private func handleKeyPress(_ press: KeyPress) -> Bool {
        guard press.key == .return, let selectedGroup else { return false }
        grouping.open(selectedGroup)
        return true
    }
}
