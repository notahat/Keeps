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
group is open, otherwise the sort screen. It uses
every other folder; nothing uses it. The document itself never saves.
