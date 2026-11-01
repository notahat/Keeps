# App

The shell. Keeps is built on AppKit's document architecture, with each open
folder as a `FolderDocument`, so AppKit provides Open, Open Recent, folders
dropped on the Dock icon, reopening folders at launch, sandbox access, and
saved window frames. This folder adds only what AppKit lacks: an Open panel
that chooses folders and shows in place of an untitled document, the main
menu, and the window that hosts each folder.

`FolderView` is where the parts meet. It owns the folder's `Grouping` and its
`KeepsFile`, restores the grouping when the window opens, saves it as it
changes, starts thumbnail prefetching, and shows the pick screen while a
group is open. Otherwise it shows the section the piles have chosen, with
`FolderPiles` as a sidebar on the left once a group is done: piles of the photos kept, still to
go, and set aside, whose counts add up to the folder. Clicking the to-go
pile shows the sort screen, and clicking the set-aside pile the done
groups; the current one sits on a highlight. The keepers pile is dragged
instead: `PhotoDragSource` hands over the keepers' files (the RAW where
there is one), the same as dragging them from Finder, for dropping into
Lightroom or a folder. `FolderWindowController` adds
the section's name to the window title. It uses every
other folder; nothing uses it. The document itself never saves.
