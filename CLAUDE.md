# CLAUDE.md

## Architecture

The code under `Keeps/` is organised by what each part of the app does.
Each folder's `README.md` describes its responsibilities; update it when
they change. The READMEs are excluded from the app target in the project
file (otherwise they'd collide as bundle resources), so a README in a new
folder needs adding to that exception list.

- `App/` — the shell, built on AppKit's document architecture, plus
  `Keeps-Info.plist` at the project root. Each open folder is a
  `FolderDocument` (the plist declares folders as a document type with
  that class), so AppKit provides Open, Open Recent, opening folders
  dropped on the Dock icon, bringing an open folder's window forward,
  reopening folders at launch (`NSQuitAlwaysKeepsWindows` is registered so
  this happens whatever the system setting), sandbox access to them,
  including after a relaunch, and saving each window's frame. The shell
  adds only what AppKit lacks: the Open panel chooses folders, and shows in
  place of an untitled document. `FolderView` owns the folder's `Grouping`
  and its `KeepsFile`, and shows the pick screen while a group is open,
  otherwise the section the user has selected by clicking a pile in
  `FolderSidebar`, beside it: the sort screen for the photos still to go,
  the done groups, or the keepers. The document never saves; `KeepsFile`
  writes keeps.json as the grouping changes.
- `Folder/` — scanning a folder into photos (`PhotoItem`, `FolderScanner`,
  `FolderSession`).
- `Images/` — loading, caching, and showing images (`ImagePipeline`,
  `FramedPhoto`, `FullSizePhoto`, load progress, `PileJitter`), and
  `ScrollingTiles`, the tile grid the pick and keepers screens share, with
  `TileLayout` its pure, tested layout.
- `Grouping/` — the model: `Grouping` holds the boundaries, collapse point,
  selection, scroll position, open and last opened groups, keepers, and
  done groups, and `GroupLayout` derives the cells.
- `Saving/` — keeps.json: `KeepsFile` reads and writes it, and
  `SavedGrouping` is its format.
- `Sort/` — the sort screen. `SortScreen` draws cells and handles input;
  `GridScrolling` does the scrolling; the logic is in pure, tested
  helpers (`PhotoGridMetrics`, `GridHitTarget`, `GridScrollResponse`).
- `Pick/` — the pick screen. `PickScreen` draws the open group's tiles in
  `ScrollingTiles` and handles the pick screen's keys.
- `Done/` — the done screen. `DoneScreen` shows the done groups as piles,
  any of which can be opened on the pick screen.
- `Keepers/` — the keepers screen. `KeepersScreen` shows the keepers of
  the done groups as tiles, any of which can be shown full size.
- `Keys/` — key and click handling the screens share (`MoveDirection`,
  `isPlainLetter`, and the `handlesKeys` and `onClick` modifiers).

**Layering.** The folders use each other only like this, with no cycles:

- App uses everything.
- Sort, Pick, Done, and Keepers use Grouping, Images, Folder, and Keys,
  and never each other.
- Grouping uses Saving and Folder, converting itself to and from
  `SavedGrouping`.
- Images uses Folder, and Keys for `ScrollingTiles`' input.
- Folder, Saving, and Keys use nothing.

Grouping, Saving, Folder, and Keys have no views (Keys has only
modifiers), which keeps them testable.

**keeps.json files already on disk must keep loading.** Real folders have
been grouped, and losing that work is not acceptable. Any change to the
saved format must still restore every earlier format, by converting it on
load, with a test that restores a hand-written file in the old format (see
`originalFormatRestores` in SavedGroupingTests). Never edit an existing
format fixture to make a test pass. The file's `"workflow"` field names
its format (`SavedGrouping.originalFormatName`, `"group-cull"`), so a new
format can be written under a new name and the old one recognised by its
name.

## Glossary

- **Photo**: one picture in the folder: a RAW file, a JPEG, or a pair of
  them with the same stem (`PhotoItem`). Code calls them photos, never
  items.
- **Group**: a run of photos between two boundaries, where the folder's
  start counts as a boundary. The photos after the last boundary aren't a
  group. No type is called plain `Group`, which SwiftUI already has; use
  `PhotoGroup` if one is needed.
- **Boundary**: the split between two groups, placed by clicking between
  photos.
- **Working point**: where grouping has reached, the first photo after the
  last boundary. It holds still on screen as groups collapse.
- **Collapsed**: a group drawn as a pile, after C. It can't be
  changed.
- **To go**: the photos not yet in a done group, shown on the sort
  screen.
- **Set aside**: the photos of a done group that weren't kept.
- **Sort screen**: the grid where the folder is split into groups.
- **Pick screen**: one group at a time, where its **keepers** are picked
  and the group is marked **done**. It takes over the whole window
  whenever a group is open.
- **Done screen**: the done groups, shown as piles, any of which can be
  opened on the pick screen.
- **Keepers screen**: the keepers of the done groups, any of which can be
  shown full size.
- **Section**: which of the sort, done, and keepers screens a window
  shows when no group is open (`FolderSection`). The user selects it by
  clicking a pile in the sidebar.
- **Cell**, **tile**, and **pile**: places a photo is shown on screen. A
  cell is one place in the sort screen's grid, a tile is one photo on the
  pick or keepers screen, and a pile is a stack of prints. Each shows
  whichever image suits its size, so none of them is named after an
  image. The sort screen identifies each cell by its photo's id.
- **Slot**: a cell's place in the sort screen's grid, with its share of
  the gap. Blank slots before the first cell keep the photos in their
  columns as groups collapse.
- **Blank print**: a white card with a grey patch, drawn in place of a
  photo while its thumbnail loads, and for the hidden layers of a pile.
- **Selected**: the one cell, tile, or pile a screen highlights, which
  the movement keys move. Not the same as keyboard focus, which says
  whether a screen gets the keys at all.
- **Thumbnail**: a photo's image scaled to 520 pixels on its longest side,
  for cells, piles, and drag images, and to stand in while a larger image
  loads. It's an image, never a place on screen.
- **Medium image**: a photo's image scaled to 1932 pixels on its longest
  side, for tiles too large for a thumbnail.
- **Full image**: the largest image read, for the full-size view and the
  largest tiles. For a RAW file it's the embedded JPEG preview; a JPEG
  file is scaled down to no more than that size.

## Build & Test

Inside Xcode, build and test with the xcode-tools `BuildProject` and
`RunAllTests` tools (as `/verify` does). Elsewhere, or for things they
can't do, such as a Release build or an archive, use `xcodebuild`:

Build:
```bash
xcodebuild -project Keeps.xcodeproj -scheme Keeps -destination 'platform=macOS' build
```

Test:
```bash
xcodebuild test -project Keeps.xcodeproj -scheme Keeps -destination 'platform=macOS'
```

Decode benchmark, timing `ImageReader` over the photos in the git-ignored
`Samples/` folder (see `Benchmarks/README.md`):
```bash
Benchmarks/run-decode-benchmark
```

## Code Style

SwiftFormat runs automatically on every `.swift` edit via a PostToolUse hook — no need to run it manually.

**Function names.** A function with side effects or I/O starts with a
verb (`readImage(from:size:)`, `makeAppMenu()`). Pure lookups and SwiftUI
view builders may keep the noun names Swift's API guidelines give them
(`photoIndex(forGap:)`, `header`). This overrides the global rule that
every function name starts with a verb.

**Closure parameters.** `$0` is fine in a one-line closure whose meaning
is plain, such as `filter { keepers.contains($0) }`. Name the parameters
where their order or meaning isn't obvious, such as
`map { index, photo in (photo.stem, index) }`, when one is used more than
once, or in nested closures.

## Testing

Tests use Swift Testing (`import Testing`, `@Test`, `#expect`) — not XCTest. Write all new tests to match this framework.

`KeepsTests/` mirrors `Keeps/`: a type's tests go in the folder of the
same name, such as `KeepsTests/Grouping/GroupingTests.swift` for
`Keeps/Grouping/Grouping.swift`. Helpers shared across folders, such as
`TestHelpers.swift`, sit at the top of `KeepsTests/`.

## Swift 6

The main target compiles under Swift 6 strict concurrency. All new code must satisfy the concurrency checker.

## Plans

Write implementation plans to `PLAN.md` at the project root and commit the plan before starting work.
