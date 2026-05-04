import SwiftUI

/// Stores user-defined photo groups for a single open folder. Each group is a
/// visual set of related photos identified by a color bar on their thumbnails.
/// Pure data store — does not know about selection, filtering, marks, or
/// persistence. Photos are referenced by ID; persistence translates those to
/// stems elsewhere so groups survive folder moves.
struct GroupStore {
    struct PhotoGroup {
        var id: UUID
        var colorIndex: Int
        var itemIDs: Set<UUID>
    }

    static let colors: [Color] = [.orange, .purple, .cyan, .yellow, .pink, .mint]

    private(set) var groups: [PhotoGroup] = []

    /// Returns the group containing the given photo, or nil if the photo isn't
    /// in any group.
    func group(containing itemID: UUID) -> PhotoGroup? {
        groups.first { $0.itemIDs.contains(itemID) }
    }

    /// Returns the color of the group containing the given photo, or nil if
    /// the photo isn't in any group.
    func color(forItem itemID: UUID) -> Color? {
        guard let group = group(containing: itemID) else { return nil }
        return GroupStore.colors[group.colorIndex]
    }

    /// Returns the color of the group with the given ID, or nil if no such
    /// group exists.
    func color(forGroup groupID: UUID) -> Color? {
        guard let group = groups.first(where: { $0.id == groupID }) else { return nil }
        return GroupStore.colors[group.colorIndex]
    }

    /// Creates a new group from the given item IDs. Items already in other
    /// groups are moved into the new group; any group left empty as a result
    /// is dropped. Returns the new group's ID.
    @discardableResult
    mutating func addGroup(itemIDs: Set<UUID>) -> UUID {
        for index in groups.indices {
            groups[index].itemIDs.subtract(itemIDs)
        }
        groups.removeAll { $0.itemIDs.isEmpty }
        let newGroup = PhotoGroup(id: UUID(), colorIndex: nextColorIndex(), itemIDs: itemIDs)
        groups.append(newGroup)
        return newGroup.id
    }

    /// Removes the group that contains the given photo, if any.
    mutating func removeGroup(containing itemID: UUID) {
        groups.removeAll { $0.itemIDs.contains(itemID) }
    }

    /// Replaces all groups with the given list. Used by persistence on restore.
    mutating func applyRestored(_ restored: [PhotoGroup]) {
        groups = restored
    }

    /// Resets to the initial empty state.
    mutating func reset() {
        groups = []
    }

    /// Picks the color index used least often among existing groups.
    private func nextColorIndex() -> Int {
        let colorCount = GroupStore.colors.count
        var usageCounts = Array(repeating: 0, count: colorCount)
        for group in groups {
            usageCounts[group.colorIndex % colorCount] += 1
        }
        return usageCounts.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
    }
}
