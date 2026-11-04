# Keeps

A macOS app for going through a folder of photos in two quick passes:
first split them into groups, then pick the keepers from each group.

## Using it

Open a folder with File > Open, or by dropping it on the Dock icon. Keeps
shows the folder's RAW and JPEG photos in order of creation date, with a
RAW and a JPEG that share a name shown as one photo.

### Sorting into groups

The sort screen shows the photos still to go as a grid.

- Click between two photos to put a boundary there, and click again to
  remove it. Hovering between photos previews the boundary.
- Press C to collapse every finished group into a pile. Collapsed groups
  can't be changed.
- Arrow keys or h/j/k/l move the selection, and Escape clears it.
- Double-click a group, or select it and press Return, to open it for
  picking. Opening a group collapses it and every group before it.

### Picking the keepers

An open group fills the window, one photo per tile.

- Arrow keys or h/j/k/l move between photos.
- F marks the photo as a keeper, or unmarks it.
- Space, or a double-click, shows the photo full size. Moving and F still
  work there, and Space or Escape goes back to the tiles.
- Return marks the group done. Its other photos go onto a pile in the
  corner, leaving just the keepers. Return again marks it not done.
- Escape goes back, leaving the group as it is.

A done group leaves the sort screen. A group with no keepers can be
marked done too, which sets all of it aside.

### Piles

Once a group is done, a sidebar shows where every photo is, as three
piles whose counts add up to the folder. Click a pile to see it:

- **Keepers**: the keepers of the done groups, as tiles. Arrow keys move
  between them, and Space or a double-click shows one full size. Drag
  this pile into Lightroom's import, or into a folder in Finder, to hand
  over the keepers' files (the RAW where there is one).
- **To go**: the sort screen.
- **Set aside**: the done groups, each as a pile. Double-click one, or
  select it and press Return, to open it again and change its keepers.

Your progress is saved as you go to a `keeps.json` file in the photo
folder, and the folder reopens where you left it. Keeps never moves,
changes, or deletes your photos.

## Building

Open `Keeps.xcodeproj` in Xcode, or see `CLAUDE.md` for the command-line
build and test commands.
