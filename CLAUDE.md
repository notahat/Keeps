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
  `FramedPhoto`, `FullSizeImage`, load progress, `PileJitter`), and
  `TileLayout`, the pure, tested tile grid the screens share.
- `Grouping/` — the model: `Grouping` holds the boundaries, collapse point,
  selection, scroll position, open and last opened groups, keepers, and
  done groups, and `GroupLayout` derives the cells.
- `Saving/` — keeps.json: `KeepsFile` reads and writes it, and
  `SavedGrouping` is its format.
- `Sort/` — the sort screen. `SortScreen` draws cells and handles input;
  `GridScrolling` does the scrolling; the geometry is in pure, tested
  helpers (`PhotoGridMetrics`, `GridHitTarget`).
- `Pick/` — the pick screen. `PickScreen` draws the open group's tiles and
  handles input, laying them out with `TileLayout`.
- `Done/` — the done screen. `DoneScreen` shows the done groups as piles,
  any of which can be opened on the pick screen.
- `Keepers/` — the keepers screen. `KeepersScreen` shows the keepers of
  the done groups as tiles, any of which can be shown full size.
- `Keys/` — key handling the screens share (`MoveDirection`,
  `isPlainLetter`, and the `handlesKeys` modifier).

**Layering.** The folders use each other only like this, with no cycles:

- App uses everything.
- Sort, Pick, Done, and Keepers use Grouping, Images, Folder, and Keys,
  and never each other.
- Grouping uses Saving and Folder, converting itself to and from
  `SavedGrouping`.
- Images uses Folder, and Keys for `MoveDirection`.
- Saving and Keys use nothing.

Grouping, Saving, Folder, and Keys have no views (Keys has only a
modifier), which keeps them testable.

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
  image.
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

## Testing

Tests use Swift Testing (`import Testing`, `@Test`, `#expect`) — not XCTest. Write all new tests to match this framework.

## Swift 6

The main target compiles under Swift 6 strict concurrency. All new code must satisfy the concurrency checker.

## Plans

Write implementation plans to `PLAN.md` at the project root and commit the plan before starting work.
