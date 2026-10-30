# Keeps

A macOS app for going through a folder of photos in two quick passes:
first split them into groups, then pick the keepers from each group.

Only the first pass exists so far. The second is planned in `PLAN.md`.

## Using it

Open a folder with File > Open, or by dropping it on the Dock icon. Keeps
shows the folder's RAW and JPEG photos in order of creation date, with a
RAW and a JPEG that share a name shown as one photo.

- Click between two photos to put a boundary there, and click again to
  remove it. Hovering between photos previews the boundary.
- Press C to collapse every finished group into a pile. Collapsed groups
  can't be changed.
- Arrow keys or h/j/k/l move the selection, and Escape clears it.

Your progress is saved as you go to a `keeps.json` file in the photo
folder, and the folder reopens where you left it. Keeps never moves,
changes, or deletes your photos.

## Building

Open `Keeps.xcodeproj` in Xcode, or see `CLAUDE.md` for the command-line
build and test commands.
