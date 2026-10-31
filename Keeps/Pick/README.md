# Pick

The pick screen, where the keepers are picked from one group at a time.
`PickScreen` shows the open group's photos as an even grid of tiles under a
header, and handles its keys: moving focus, F to keep, Space for a
full-size view, Return to mark the group done and move on, and Escape to go
back. Tiles scale up the sort screen's thumbnails for now.

The full-size view is shown over the tiles rather than in place of them,
and you stay on the pick screen while it's up: the tiles keep keyboard
focus, and `PickScreen` handles its keys too. `PhotoDetailSurface` only
draws it, loading full images for the current photo and its neighbours.

`TileLayout` is the pure, tested part: the column count, tile size, and
positions, where the movement keys go, how far to scroll to reveal a tile,
and the group's common aspect ratio.

Uses Grouping, Images, Folder, and Keys, and never Sort.
