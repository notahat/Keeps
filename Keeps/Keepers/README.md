# Keepers

The keepers screen, which the user reaches by clicking the keepers pile in
the sidebar: the keepers of the done groups, in the same order as the pile,
the latest group's first. `KeepersScreen` lays them out as tiles with
`TileLayout`, so a few keepers fill the window and many scroll, and
handles its keys: moving the selection, and Space or a double-click for a
full-size view, which fades in over the tiles. Escape or Space goes back.

It only shows the keepers. The user changes them on the pick screen.

Uses Grouping, Images, Folder, and Keys, and never Sort, Pick, or Done.
