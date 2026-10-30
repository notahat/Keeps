# Sort

The sort screen, where the folder is split into groups. `SortScreen` draws
a grid of `SortCell`s, one per photo or collapsed group, and handles input:
clicks between photos toggle boundaries, clicks on photos select them, and
keys move the selection, clear it, or collapse finished groups.
`GridScrolling` does the scrolling: holding the working point still as
groups collapse, restoring the saved position, and following keyboard
selection.

The geometry is in pure, tested helpers: `PhotoGridMetrics` for rows,
slots, and scroll offsets, `GridHitTarget` for whether a click landed on a
photo or a gap, and `PileJitter` for how a collapsed pile is drawn. Uses
Grouping, Images, and Folder, and never Pick.
