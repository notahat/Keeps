# Pick

The pick screen, where the keepers are picked from one group at a time.
`PickScreen` shows the open group's photos as an even grid of tiles under a
header, and handles its keys: moving focus, F to keep, Return to mark the
group done and move on, and Escape to go back. Tiles scale up the sort
screen's thumbnails for now.

`TileLayout` is the pure, tested part: the column count, tile size, and
positions, where the movement keys go, how far to scroll to reveal a tile,
and the group's common aspect ratio. `PhotoDetailSurface`, a full-window
view of one photo, isn't used yet and will become the full-size view (see
PLAN.md).

Uses Grouping, Images, Folder, and Keys, and never Sort.
