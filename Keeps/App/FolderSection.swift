/// Which screen a folder window shows when no group is open: the sort
/// screen, for the photos still to go, the done screen, for the done
/// groups, or the keepers screen, for their keepers. The pick screen isn't
/// a section: it takes over the window whenever a group is open, whatever
/// the section. The user selects the section by clicking a pile in the
/// sidebar (FolderSidebar). See FolderView.
nonisolated enum FolderSection {
    case toGo, done, keepers

    /// The section's name, as the window title shows it.
    var title: String {
        switch self {
        case .toGo: "To go"
        case .done: "Done groups"
        case .keepers: "Keepers"
        }
    }

    /// This section, or the to-go section when this one has nothing left to
    /// show. The sidebar hides the pile for an empty section, so without
    /// this the user would be left on a screen with no pile to leave it by.
    func availableSection(hasDoneGroups: Bool, hasKeepers: Bool) -> FolderSection {
        switch self {
        case .toGo: .toGo
        case .done: hasDoneGroups ? .done : .toGo
        case .keepers: hasKeepers ? .keepers : .toGo
        }
    }
}
