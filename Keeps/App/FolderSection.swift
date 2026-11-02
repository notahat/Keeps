/// Which screen a folder window shows when no group is open: the sort
/// screen, for the photos still to go, or the done screen, for the done
/// groups. The pick screen isn't a section: it takes over the window
/// whenever a group is open, whatever the section. The user selects the
/// section by clicking a pile in the sidebar (FolderSidebar). See
/// FolderView.
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
