# App

The shell. Keeps is built on AppKit's document architecture, with each open
folder as a `FolderDocument`, so AppKit provides Open, Open Recent, folders
dropped on the Dock icon, reopening folders at launch, sandbox access, and
saved window frames. This folder adds only what AppKit lacks: an Open panel
that chooses folders and shows in place of an untitled document, the main
menu, and the window that hosts each folder.

The app has three main screens: sort, pick, and done. The pick screen takes
over the whole window whenever a group is open. Otherwise the window shows
either the sort screen or the done screen, and which of those two it shows
is the section (`FolderSection`).

`FolderView` is where the parts meet. It owns the folder's `Grouping` and its
`KeepsFile`, restores the grouping when the window opens, saves it as it
changes, starts thumbnail prefetching, and shows the pick screen while a
group is open. Otherwise it shows the section the user has selected, with
`FolderSidebar` on the left once a group is done: piles of the
photos kept, still to go, and set aside, whose counts add up to the
folder. The user selects a section by clicking a pile: the to-go pile for
the sort screen, or the set-aside pile for the done groups. The pile for
the section showing sits on a highlight. The
keepers pile is dragged instead: `PhotoDragSource` hands over the keepers'
files (the RAW where there is one), the same as dragging them from Finder,
for dropping into Lightroom or a folder. `FolderWindowController` adds the
section's name to the window title. It uses every other folder; nothing
uses it. The document itself never saves.
