# Sort

The sort screen, where the folder is split into groups. `SortScreen` draws
a grid of `SortCell`s, one per photo or collapsed group, and handles input:
clicks between photos toggle boundaries, clicks on photos select them, and
keys move the selection, clear it, or collapse the groups closed so far.
Double-clicking a closed group, or pressing Return on it, opens it on the
pick screen. `GridScrolling` does the scrolling: holding the working point
still as groups collapse, restoring the saved position, and following
keyboard selection.

A collapsed group is drawn as Images' `PrintPile`, in Grouping's `Pile`
order (keepers on top), with its photo count. Done groups have no cell:
they've left the grid. Once every photo is in a done group,
`AllDoneMessage` shows in place of the empty grid.

The geometry is in pure, tested helpers: `PhotoGridMetrics` for rows,
slots, scroll offsets, and where the movement keys go, and `GridHitTarget`
for whether a click landed on a photo or a gap. Uses Grouping, Images,
Folder, and Keys, and never Pick.
