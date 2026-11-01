# Pick

The pick screen, where the keepers are picked from one group at a time.
`PickScreen` shows the open group's photos as an even grid of `PickTile`s
under a header, and handles its keys: moving focus, F to keep, Space for a
full-size view, Return to mark the group done or not, and Escape to go
back. Tiles scale up the sort screen's thumbnails for now.

Once the group is done, only its keepers are tiles, re-flowed beside a
`SetAsidePile` in the bottom-right corner holding the photos that weren't
kept, and F does nothing. `PickArrangement` is the pure, tested
part that says which photos are tiles and which are on the pile.

The full-size view (`FullSizeView`) is shown over the tiles rather than in
place of them, and you stay on the pick screen while it's up: the tiles
keep keyboard focus, and `PickScreen` handles its keys and decides when it
zooms. It zooms out of the focused tile and back into it (a fade with
Reduce Motion on), which shows where you are in the grid on the way back.
`FullSizeImage`, inside it, loads and draws the photo, showing the
thumbnail while the full image loads and preloading its neighbours.

`TileLayout` is the pure, tested part: the column count, tile size, and
positions, where the movement keys go, how far to scroll to reveal a tile,
and the group's common aspect ratio.

Uses Grouping, Images, Folder, and Keys, and never Sort.
