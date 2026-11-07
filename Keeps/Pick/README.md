# Pick

The pick screen, where the keepers are picked from one group at a time.
`PickScreen` shows the open group's photos as an even grid of `PickTile`s
under a header, and handles its keys: moving the selection, F to keep,
Space for a full-size view, Return to mark the group done or not, and
Escape to go back.

Once the group is done, only its keepers are tiles, re-flowed beside a
`SetAsidePile` in the bottom-right corner holding the photos that weren't
kept, and F does nothing. `PickArrangement` is the pure, tested
part that says which photos are tiles and which are on the pile.

The full-size view (`FullSizeView`) is shown over the tiles rather than in
place of them, and you stay on the pick screen while it's up: the tiles
keep keyboard focus, and `PickScreen` handles its keys and controls when it
zooms. It zooms out of the selected tile and back into it (a fade with
Reduce Motion on), which shows where you are in the grid on the way back.
`FullSizePhoto`, from Images, loads and draws the photo inside it.

`ScrollingTiles`, from Images, lays out the tiles, scrolls them when they
don't fit, and handles clicks and the movement keys, leaving `PickScreen`
the other keys.

This folder uses Grouping, Images, Folder, and Keys, and never another
screen's folder: Sort, Pick, Done, and Keepers don't use each other.
