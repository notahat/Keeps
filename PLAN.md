# Plan: GroupCull — grouping photos by clicking between them

## Goal

Experiment with a culling UI that limits what you see at once and gives a
sense of progress. The hypothesis is two fast passes: first group photos,
then pick a few keepers from each group. This plan covers **grouping only**.
Selection gets its own design session once grouping has been tried.

## Design

- **New workflow.** `Keeps/Workflows/GroupCull/`, swapped in via the wiring
  line in `ContentView`. `SimpleCull` stays untouched for comparison.
- **Linear sweep.** You work front to back. The folder always starts a group
  before the first photo. Photos after the last boundary are ungrouped
  (unreached) and are shown normally.
- **Boundaries.** Clicking between two photos toggles a boundary there. The
  click targets are edge zones (roughly the outer 20% of each cell's width),
  not the thin gap itself. An edge click never selects the photo. Hovering
  an edge zone previews the boundary. A boundary is drawn as a vertical bar
  in the gap, or in the margin at a row's start or end. The right edge of
  the last cell in a row and the left edge of the first cell in the next row
  are the same gap. The gap before the first photo is ignored. Placing a
  boundary never reflows the layout.
- **Finishing.** A boundary after the last photo closes the final group.
- **Collapsing is manual.** Pressing C collapses every group closed so far;
  groups closed afterwards stay open until the next press. The workflow
  stores only the photo index collapsing reaches. There is no un-collapse.
  (Automatic collapsing of all but the two most recent groups was tried
  first and dropped.)
- **Layout stability.** Nothing you're looking at moves when groups
  collapse. The grid leaves blank slots before the first cell for the
  photos hidden inside collapsed groups (modulo the column count), so open
  photos keep their original columns. The working point (the first photo
  after the last boundary) is held at the same height on screen. Before
  there is one, a click holds the clicked photo and a key press holds the
  photo in the middle of the view. A click never scrolls the selection into
  view. Changes are not animated.
- **Collapsed group.** Shown as one cell: a messy pile of up to eight of
  the group's photos as white-bordered prints, with a count badge.
  Collapsed groups are finished: the gaps on either side show no boundary
  bar and can't be toggled.
- **Selection.** The folder opens with nothing selected, and Escape clears
  the selection. Clicking a collapsed group selects it; it does not expand.
  (Temporary expansion for editing was tried and set aside for now.)
- **Full-size view.** Double-click opens the existing detail surface,
  read-only; Esc returns. No boundary editing from the full-size view.
- **Persistence.** `keeps.json` state under the workflow name `group-cull`,
  so a folder reopens exactly where it was left: each boundary (as "before
  this photo's stem" or "end"), the collapse point, the selected photo, and
  the scroll position. Stems no longer in the folder are dropped when the
  state is loaded.
- **Input.** Boundaries are placed with the mouse. The keyboard has C to
  collapse, Escape to clear the selection, and arrow-key navigation as the
  surface provides it.

### Kit boundary

Kit learns a generic, spatial notion of a *gap*: "the gap before item i".
`PhotoGridSurface` resolves a click to either an item or a gap, reports
which gap the pointer is hovering, and maps both sides of a row wrap to the
same gap. It knows nothing about groups or boundaries. The workflow turns
gap clicks into boundary toggles, keeps track of the hovered gap Kit
reports, and draws the bars in its own cells. These callbacks are optional,
so SimpleCull's behaviour is unchanged.

### Out of scope

Picking keepers, progress indicators, dimming or truncating unreached
photos, putting each group on its own row, keyboard boundary toggling, and
boundary suggestions from time gaps. Photos are ordered by file creation
date and EXIF capture times are not read, so time-gap suggestions would
need that first.

## Steps

Each step includes tests where there is testable behaviour, then review and
commit.

1. ✅ **Gap hit-testing in Kit.** A pure function mapping a click position
   within a cell (plus the cell's width and index) to an item or a gap
   index, covering the row-wrap equivalence and the ignored leading gap.
   Tested with Swift Testing. Add optional `onGapTap` and hover-gap
   reporting to `PhotoGridSurface`, and suppress item selection for edge
   clicks.
2. ✅ **Grouping model.** `GroupCull` state holding the boundary set and the
   collapse point, and a pure derivation from photos plus boundaries to
   groups, collapsed or open status, and the list of cells to display.
   Toggling, finishing, and collapsing are covered by tests.
3. ✅ **Grouping UI.** The root view wired into `ContentView`, cell chrome
   drawing the boundary bars and hover preview, and gap clicks toggling
   boundaries. First point where the app can be tried.
4. ✅ **Collapsing.** Pressing C collapses closed groups into messy-pile
   cells with a count badge, holding the working point still.
5. ✅ **Persistence.** The `group-cull` state schema with snapshot and
   restore of boundaries, collapse point, selection, and scroll position,
   tested like `SimpleCullStateTests`.
6. ~~**Read-only detail view.**~~ Replaced by the group screen's full-size
   view in "Narrowing each group to its keepers" below.

---

# Plan: Keeps as an AppKit document app

## Goal

Stop reimplementing standard Mac document behaviour by hand. Each folder
becomes an `NSDocument`, and AppKit's document machinery provides what the
SwiftUI shell builds itself today: Open, Open Recent, opening folders
dropped on the Dock icon, bringing forward a folder's existing window, the
title bar's folder icon, the Open panel when there's nothing to show, and
regaining sandbox access to folders on relaunch.

A throwaway experiment confirmed all of this works for folders in the
sandboxed app, including the Open panel at launch and on a Dock click with
no windows open, with Open Recent still usable while that panel is up.

## Design

- **Entry point.** `main.swift` replaces the SwiftUI `App`. It makes the
  document controller, sets the app delegate and main menu, and runs the
  app, all inside `MainActor.assumeIsolated`, since top-level code isn't
  main-actor isolated here.
- **Folders as documents.** `Keeps-Info.plist` declares `public.folder` as a
  document type with the Viewer role, an `Alternate` handler rank (Finder
  keeps opening folders on double-click), and `FolderDocument` as its class.
- **`FolderDocument`.** An `NSDocument` that overrides
  `read(from:ofType:)` to open a `FolderSession`, so AppKit never loads the
  folder into a file wrapper. It never saves and doesn't autosave.
  `keeps.json` keeps being written by the workflow's own persistence, as
  now. A folder that can't be read fails to open, and AppKit reports the
  error, so windows no longer need an error state.
- **Window.** `FolderDocument` makes a window controller whose window hosts
  the workflow's root view in an `NSHostingController`. The one wiring line
  a workflow experiment replaces moves there from `ContentView`. The "no
  photos" message stays.
- **Document controller.** A small `NSDocumentController` subclass lets the
  Open panel choose folders and not files.
- **App delegate.** When AppKit asks for an untitled document (at launch
  with nothing to restore, or on a Dock click with no windows), it shows
  the Open panel instead, since a folder can't be untitled.
- **Main menu.** Built in code: the app menu (About, Hide, Quit), File
  (Open…, Close), and Window. AppKit adds Open Recent next to Open… by
  itself, even in a code-built menu (the experiment's own Open Recent
  showed up as a duplicate), so the menu doesn't include one.
- **Window frames.** Still kept in each folder's `keeps.json`. The window
  controller applies the saved frame before the window is first shown,
  which removes today's hide-then-reveal trick, and saves moves and
  resizes, skipping full screen, as now.
- **Reopening at launch.** AppKit's standard window restoration. By
  default macOS only restores windows when the user has turned off "Close
  windows when quitting an application"; that default is acceptable. Last
  step: try registering `NSQuitAlwaysKeepsWindows` to always restore.

### Removed

The SwiftUI shell that AppKit replaces: `KeepsApp`, `ContentView`,
`FolderReference` (bookmarks are no longer needed), `OpenFolderList`,
`RecentFolders`, `FolderWindows`, `FolderCommands`, `FolderPicker`, and
`AppLifecycle`, with their tests.

### Out of scope

Following a folder that's renamed or moved while open: `NSDocument`
updates its URL, but the open `FolderSession` keeps the old one. Kit and
the workflows don't change.

## Steps

Each step includes tests where there is testable behaviour, then review and
commit. The shell has little logic of its own, so most checking is by
running the app.

1. ✅ **Switch to AppKit documents.** Entry point, app delegate, document
   controller, main menu, `FolderDocument` and its window controller
   hosting the workflow, and the plist changes. Remove the SwiftUI shell.
   Windows open at the default size until step 2. Check by hand: Open
   panel at launch and on a Dock click, Open and Open Recent, Dock drops
   (running and at launch), reopening an open folder brings its window
   forward, an unreadable folder reports an error.
2. ✅ **Window frames in keeps.json.** Apply the saved frame before the window
   shows, and save moves and resizes. The frame's reading and writing is
   tested against a temporary folder.
3. ✅ **Always reopen folders.** Register `NSQuitAlwaysKeepsWindows` and check
   folders come back after quitting whatever the system setting. Drop it
   if it misbehaves.
4. ✅ **Docs.** Update the shell description in `CLAUDE.md`.

---

# Plan: Narrowing each group to its keepers

## Goal

The second pass: pick the one or two photos worth keeping
from each group, then mark the group done. The screen shows one group at a
time and nothing else, so narrowing never feels overwhelming. This is a
starting point to experiment from, not a final design.

## Design

- **Opening a group.** Double-click or Return on a closed group in the sort
  screen (one with a boundary after it) opens the pick screen. Ungrouped photos
  past the working point can't be opened. Opening a group collapses every
  group up to and including it, as if C had been pressed with the last
  boundary at the end of that group. C itself is unchanged. Groups that are
  already done can be reopened, with their keepers still marked.
- **Pick screen.** Only the group's photos, plus a quiet header such as
  "Group 12 of 47" (counting closed groups). One photo has focus.
- **Tile layout.** An even grid. Every column count from 1 to the photo
  count is tried, and the one giving the largest tiles wins. Cells take the
  group's most common aspect ratio, and each photo is fitted inside its
  cell. A short last row is centred. Tiles stop shrinking at a minimum
  size, and past that the grid scrolls. Nothing moves while you're in the
  group.
- **Keys.**
  - hjkl and the arrows move focus.
  - Space toggles a full-size view of the focused photo. Moving and marking
    still work while full-size.
  - F toggles keep on the focused photo.
  - Return marks the group done and opens the next closed group that isn't
    done. When there isn't one, it returns to the sort screen with the
    working point in view.
  - Escape returns to the sort screen without changing whether the group
    is done.
- **Keepers.** Shown with a clear badge or border. The other photos stay at
  full brightness on the pick screen.
- **Done groups on the sort screen.** A done group is always collapsed, so only
  piles show done status. The keepers sit on top of the pile, and the badge
  shows a checkmark and "2 of 7". A done group with no keepers is allowed,
  meaning the whole group is rejected; its pile is dimmed and shows "0 of
  7". Piles that aren't done look as they do now.
- **Persistence.** `SavedGrouping` gains the keepers (as stems) and
  the done groups (as the stem of each group's first photo). Both are
  optional, so existing `keeps.json` files still load.

### Implementation

- **New tiles, not the sort screen's grid.** The sort screen's cells have
  a fixed size and their column count follows the window width; the pick
  screen picks its column count first and the tile size follows. Most of
  the sort screen's code (`GridScrolling`, blank slots, gap clicks) is
  irrelevant here, and a group is too small to need a lazy grid.
- **Shared key handling.** The hjkl/arrow-to-direction code moves out of
  `SortScreen` into a small helper that both screens use. The pick
  screen's letter keys also need `SortScreen.handleCommandKey`'s check
  that ⌘, ⌃, and ⌥ aren't held, so F doesn't catch ⌘F.
- **Layout (`Pick/`, pure).** Takes the photo count, the aspect ratio, the
  available size, the spacing, and a minimum tile size. Returns the column
  count, the tile size, each tile's position, and whether the tiles need
  to scroll. It also decides where j and k go when the short last row is
  centred: the nearest tile horizontally.
- **Tiles (`Pick/`).** Measures the space, runs the layout, places the
  tiles, and scrolls only when they don't fit. Takes focus and keys, and
  passes each tile its size.
- **Larger images.** Tiles may be several times thumbnail size, so
  `ThumbnailImage` takes its display size as a parameter, and requests are
  rounded up to a few fixed pixel sizes so that resizing the window doesn't
  decode everything again.
- **Aspect ratios before layout.** Photos don't store their dimensions.
  The grid will usually have loaded every photo's thumbnail, so the cached
  thumbnails give the aspect ratios; a photo whose thumbnail isn't cached
  needs a fallback, such as reading its pixel size from the file header.
- **Image loading and caching needs experimenting with.** Today each pixel
  size is a separate cache entry, a larger size doesn't use a smaller one
  as a placeholder while it loads, and the cache has no size limit, so
  only memory pressure evicts anything. How sizes are loaded, cached, and
  reused (including keeping known dimensions somewhere) may change as the
  pick screen is tried, and memory use should be profiled.
- **Full-size view.** `PhotoDetailSurface`, given only the group's photos,
  shown over the tiles like a popover: the tiles keep keyboard focus and
  `PickScreen` handles its keys, since moving focus to it from code didn't
  take. It only draws and preloads neighbours.
- **Model and screens.** `FolderView` switches between the sort screen and
  the pick screen, from a view mode on `Grouping`. `Grouping` gains the
  open group, keepers, and done groups. The pick screen is the header
  plus either the tiles or the full-size view.
- **Borrowing from the removed SimpleCull workflow.** SimpleCull was deleted
  before this work began. Copy what helps rather than reviving it. View
  any of its files as they last stood with
  `git show 12dbc04:Keeps/Workflows/SimpleCull/<file>`. Worth a look:
  - `SimpleCullRootView.swift`: picking a screen from a view mode (the
    "Model and screens" bullet above).
  - `SimpleCullDetailScreen.swift`: a template for the full-size view
    (step 6). It wires `PhotoDetailSurface` to the selection, uses Escape
    to go back, and overlays a badge and an "n / total" counter. Its
    `onNavigate` took a `NavigationProposal`; it now takes the target
    index directly.
  - `MarkIcon.swift` and `MarkBadge` in `SimpleCullCell.swift`: a white
    checkmark on a green circle with a shadow, a candidate keeper badge
    for step 4 and done piles in step 7.

### Out of scope

Regrouping after collapse: once a group is collapsed, its boundaries can't
change. Zooming beyond full-size, synced zoom across a group, a "keep and
finish" key, and animated transitions between groups. Deciding what
happens to photos that weren't kept (moving or deleting them).

## Steps

Each step includes tests where there is testable behaviour, then review and
commit.

1. ✅ **Shared key handling.** (`MoveDirection` and `isPlainLetter`, in a
   new `Keys/` folder both screens use.) Move the hjkl/arrow-to-direction code out of
   `SortScreen` into a helper both screens can use, and have
   `PhotoDetailSurface` use it in place of its own copy. That copy doesn't
   lowercase, so h/j/k/l there gain Caps Lock support; otherwise no change
   in behaviour. Tested.
2. ✅ **Narrowing model.** Keepers and done groups in `Grouping`: toggling a
   keeper, marking a group done, opening a group (collapsing up to it),
   and finding the next closed group that isn't done. Tested.
3. ✅ **Even-grid layout.** (`TileLayout`; the minimum applies to a tile's
   longer side.) The pure layout function in `Pick/`: column
   choice, centred last row, the minimum tile size, and j/k targets.
   Tested.
4. ✅ **Pick screen.** (`PickScreen`. Opening a group also selects it, so
   the sort screen shows it on return. `ThumbnailImage` gained a
   `frameSize`, still loading the same thumbnail.) The tiles, aspect ratios from cached thumbnails, and
   the pick screen with its header, F, Return, and Escape, opened by
   double-click or Return from the sort screen. Tiles scale up the sort
   screen's existing thumbnails, so there's no new image loading and it's
   quick to try. First point where narrowing can be tried. Give sort cells
   the double-click as `onTapGesture(count: 2)` with the single click as a
   `simultaneousGesture(SpatialTapGesture())`: a plain single-tap gesture
   waits out the double-click timeout, which makes selection lag.
5. ~~**Image sizes and caching.**~~ Replaced by "Measuring, then
   sharpening the tiles" below. Exploratory: `ThumbnailImage` taking its
   size, larger images for tiles, then trying the pick screen and the
   sort screen, profiling memory, and adjusting how sizes are loaded, cached, and
   reused, including the fallback for unknown aspect ratios. Tests are
   written once the shape settles.
6. ✅ **Full-size view.** (Done before step 5. Escape at full size goes
   back to the tiles; double-clicking a tile also opens it full size. It
   covers the tiles, which keep focus; see "Full-size view" above. It
   zooms out of the focused tile and back in with `matchedGeometryEffect`,
   showing the thumbnail until the full image loads.)
   Space toggles `PhotoDetailSurface` for the focused
   photo, with movement and F still working.
7. ✅ **Done status on collapsed groups.** (`Pile`, in `Sort/`. Keepers go
   on top of any pile, done or not.) Keepers on top of the pile, the checkmark and
   "2 of 7" badge, and dimming for groups with no keepers.
8. ✅ **Persistence.** (`keeperStems` and `doneGroupStartStems`, optional
   and left out when empty, under the same format name. The open group
   isn't saved, so a relaunch shows the sort screen.) Keepers and done groups in `SavedGrouping`, with old
   files still loading. Tested like `SavedGroupingTests`.

---

# Plan: Structure the app around what it does

## Goal

The code is split into a workflow-neutral Kit and a GroupCull workflow, a
split made for swapping between several workflows. There is now only one,
and the split costs more than it gives: `PhotoGridSurface` describes
everything in neutral terms (items, gaps, blank slots, a stable item), and
`GroupCullGridScreen` translates them back into groups. Organise the code
by what each part of the app does instead, and drop the names "GroupCull"
and "Cull". Do this before the narrowing plan above, which is written in
the new names.

## Vocabulary

- **Group**: a run of photos between two boundaries. Not "pile", and no
  type is called plain `Group`, which SwiftUI already has; use
  `PhotoGroup` if a single group ever needs a type.
- **Sort screen**: the grid where the folder is split into groups.
- **Pick screen**: one group at a time, where its keepers are picked.
- **Keepers**, **done**, **boundary**, and **working point** keep their
  meanings.
- `"group-cull"` survives only as the name of the original keeps.json
  format, as `SavedGrouping.originalFormatName`.

| Now | New |
|---|---|
| GroupCullWorkflow | Grouping |
| GroupCullGridScreen + PhotoGridSurface | SortScreen + GridScrolling |
| GroupCullCell | SortCell |
| GroupCullRootView | merged into FolderView |
| GroupCullState | SavedGrouping |
| WorkflowPersistence | KeepsFile |
| NavigationProposal | removed |

## Design

```
Keeps/
  App/       main, AppDelegate, MainMenu, FolderDocumentController,
             FolderDocument, FolderWindowController, FolderView
  Folder/    PhotoItem, FolderScanner, FolderSession
  Images/    ImagePipeline, ImageCache, ImageReader, ImageSize,
             ThumbnailImage, LoadProgress, LoadProgressView
  Grouping/  the model: Grouping (later also keepers and done groups),
             GroupLayout, GridScrollAnchor
  Saving/    keeps.json: KeepsFile (reading and writing), SavedGrouping
             (the format), and later the old-format conversions
  Sort/      the sort screen: SortScreen, GridScrolling, SortCell,
             PileJitter, PhotoGridMetrics, GridHitTarget
  Pick/      the pick screen (narrowing plan): PickScreen, tile layout,
             tiles, full-size view (PhotoDetailSurface)
```

- **SortScreen** merges `PhotoGridSurface` and `GroupCullGridScreen`. It
  reads the layout's cells itself, calls `selectCell`, `toggleBoundary`,
  and `collapseClosedGroups` directly, and keeps the hovered gap as its own
  state. `displayedItems`, `NavigationProposal`, the generic cell closure,
  and the unused double-tap callback go.
- **GridScrolling** holds the scroll behaviour, the bulk of today's
  `PhotoGridSurface`: holding the working point still as groups collapse,
  restoring the saved position, following keyboard selection, and
  reporting the scroll position. A view modifier or small helper, so
  SortScreen only draws cells and handles input.
- **FolderView** absorbs `GroupCullRootView`: it creates the `Grouping`
  and its `KeepsFile`, and shows the sort screen (and later picks between
  the sort and pick screens).
- **KeepsFile** reads and writes `SavedGrouping` only, no longer generic
  over the state or the workflow name. It still writes the envelope with
  `"workflow": "group-cull"`, and still recognises files by it, so every
  existing keeps.json loads unchanged. `originalFormatRestores` must pass
  untouched throughout.
- **Layering**, replacing "Kit never imports from Workflows". Each arrow
  means "uses", and there are no cycles. Folder, Images, and Saving know
  nothing about groups as the app models them (Saving holds only the
  saved form); Grouping knows nothing about views; neither screen uses the
  other.

  ```mermaid
  graph TD
      App --> Sort
      App --> Pick
      App --> Grouping
      App --> Saving
      App --> Images
      App --> Folder
      Sort --> Grouping
      Sort --> Images
      Sort --> Folder
      Pick --> Grouping
      Pick --> Images
      Pick --> Folder
      Grouping --> Saving
      Grouping --> Folder
      Images --> Folder
  ```

  App uses Images to prefetch thumbnails and show loading progress.
  Grouping uses Saving because it converts itself to and from
  `SavedGrouping`. `GridScrollAnchor` lives in Grouping, not Sort, because
  Grouping holds the saved scroll position.
- `PileJitter` keeps its name: it describes how a collapsed group is
  drawn, not a concept. The `Grid…` and `PhotoGrid…` helpers keep theirs:
  they're about grid geometry, not sorting.
- `PhotoDetailSurface` is unused until the pick screen's full-size view,
  and moves to `Pick/` as it is.

### Out of scope

Any change in behaviour, and any change to the keeps.json format.

## Steps

Each step builds and passes the tests, then review and commit. No step
changes behaviour. Steps 3–5 touch views, which have no automated tests,
so check by hand: clicking boundaries and the hover preview, C to collapse
with the working point held still, arrow and hjkl keys, Escape, and
reopening a folder at its saved scroll position and selection.

1. ✅ **Move and rename.** Files into the folders above (the Xcode groups
   follow the file system, so `git mv` is enough), and the type renames
   from the table, with their tests (`GroupingTests`,
   `SavedGroupingTests`, `KeepsFileTests`) and `makeGrouping` in
   TestHelpers. `SavedGrouping.originalFormatName` replaces
   `workflowName`. Nothing merged yet.
2. ✅ **Specific saving.** `KeepsFile` saves and restores `SavedGrouping`
   only. Its tests move from the stub state to `SavedGrouping`.
3. ✅ **FolderView owns the grouping.** Merge `GroupCullRootView` into
   `FolderView`.
4. ✅ **One sort screen.** Merge `PhotoGridSurface` into `SortScreen`, reading
   the grouping directly. Remove `NavigationProposal`. (`displayedItems`
   stayed on `Grouping` as `cellItems`, since the screen still needs it and
   it is tested there.)
5. ✅ **Split out the scrolling.** Move the scroll behaviour from
   `SortScreen` into `GridScrolling`.
6. ✅ **Docs.** Rewrite the architecture section of `CLAUDE.md` for the new
   folders and layering, add the vocabulary above as a glossary, and
   update the keeps.json rule's test reference.

---

# Plan: Tidying for readability

## Goal

Make the code easier to follow, mainly by splitting `PickScreen`, the one
file doing too many jobs. No change in behaviour, and no change to the
keeps.json format.

## Steps

Each step builds and passes the tests, then review and commit. Views have
no automated tests, so check the pick screen by hand after steps 1, 2, and
4: moving, F, Space and double-click zooming in and out, Return, and
Escape.

1. ✅ **Split `PickScreen`.** (`PickTile.swift` and `FullSizeView.swift`;
   the enum, `FullSizeState`, was kept.) `PickTile` and `KeeperBadge` move to their own
   file, and the full-size view to its own view, with `PickScreen` keeping
   the zoom state and passing in the namespace. A helper turns a place in
   the group into a photo index. Try one zoom-state enum in place of
   `isFullSize` and `isZoomed`, kept only if it reads better.
2. ✅ **Simplify the full-size photo.** (Named `FullSizeImage` instead, to
   match `ThumbnailImage`.) `PhotoDetailSurface` becomes
   `FullSizePhoto`: a non-optional index and no overlay closure, since the
   caller can add its own overlay.
3. ✅ **Sort keys in `PhotoGridMetrics`.** (`targetCell`.) The arrow-key target cell moves
   from `SortScreen` into `PhotoGridMetrics`, tested, as does `slotWidth`.
4. ✅ **Shared keyboard focus.** (`handlesKeys`.) One modifier in `Keys/` for the focusable,
   focused, key-handling setup both screens repeat.
5. ✅ **Shorter save conversion.** (`PhotoStems`.) A small pure helper in `Grouping/` for
   converting between photo indices and stems, tested.

---

# Plan: Piling up a done group on the pick screen

## Goal

Make finishing a group feel more tangible. When Return marks the open group
done, its photos that weren't kept move into a pile in the pick screen's
bottom-right corner, the keepers re-flow into the space left, and the group
stays open. A done group always shows this way, including when it's
reopened from the sort screen.

Out of scope for now: animating the move, moving on to the next group
(Return on a done group does nothing; Escape goes back), and any way to
undo it. No change to the keeps.json format, which already saves keepers
and done groups.

## Steps

Each step builds and passes the tests, then review and commit.

1. ✅ **Share the pile jitter.** Move `PileJitter` from `Sort/` to `Images/`,
   so the pick screen's pile can tilt its prints the same way the sort
   screen's do without Pick using Sort.
2. ✅ **Return marks done and stays.** `Grouping.finishOpenGroup()` becomes
   `markOpenGroupDone()`, which marks the open group done and leaves it
   open. Tested in place of the tests for moving on.
3. ✅ **Which photos are tiles.** (`PickArrangement`.) A pure, tested helper in `Pick/` that says
   which of a group's photos are laid out as tiles (all of them, or only
   the keepers once done) and which are on the pile, and where focus lands
   when the group becomes done.
4. ✅ **Draw the pile.** (`SetAsidePile`.) `PickScreen` lays the tiles out beside a pile in the
   bottom-right corner once the group is done, with a count of the photos
   on it. Movement keys and the full-size view cover only the tiles, and F
   does nothing on a done group. Check by hand: finish a group with some
   keepers, none, and all; reopen a done group from the sort screen.

---

# Plan: Done groups leave the sort screen

## Goal

Finished work gets out of the way. A done group's cell leaves the sort
screen's grid, and its keepers go onto a pile of everything kept so far,
labelled with how many were kept from how many groups. The grid shrinks as
the pile grows. Leaving a done group selects the next group that isn't
done, so Return opens it.

The pile starts in the bottom-right corner, but that may take too much
room, so it's its own view placed in one spot in `SortScreen`, easy to
move.

Out of scope for now: reopening a done group (the pile only shows),
animation, and undo. No change to the keeps.json format.

Scrolling should need no new code: the blank slots before the first cell
already keep open photos in their columns when cells go, and the working
point is already held still. Gaps beside collapsed groups are already
locked, so hiding one unlocks nothing.

## Steps

Each step builds and passes the tests, then review and commit.

1. ✅ **Select the next group on leaving a done one.** When
   `closeOpenGroup()` closes a done group, the selection moves to the first
   photo of the next closed group that isn't done, or the working point if
   there is none. Tested.
2. ✅ **Leave done groups out of the grid.** `GroupLayout` takes the done
   groups and leaves their cells out, still counting their photos as
   hidden; `Grouping` passes them in and re-lays out when they change.
   Tested, including that the gaps either side stay locked. `Pile` loses
   its done state and fading, which nothing draws any more. Check by hand
   that the grid doesn't jump on returning from a done group.
3. ✅ **Share the pile of prints.** (With `PileLabel` for the caption.) The drawing of a messy pile of prints
   moves from `SetAsidePile` into `Images/` as `PrintPile`, so the sort
   screen can draw one too without using Pick.
4. ✅ **What's been kept.** `Grouping` gives the keepers of the done groups
   in pile order (the latest on top) and how many groups are done.
   Tested.
5. ✅ **Draw the kept pile.** A `KeptPile` view in `Sort/`, laid over the
   grid's bottom-right corner while any group is done, labelled like "48
   kept from 12 groups". Check by hand.

---

# Plan: Piles as navigation, and un-marking a done group

## Goal

Three piles beside the sort screen show where every photo in the folder
is, and their counts add up to the folder:

- **To go**: photos not yet in a done group, the next up on top.
- **Keepers**: the done groups' keepers.
- **Set aside**: the done groups' other photos.

Clicking a pile shows its view: to go is the sort screen, and set aside
shows the done groups, each as a pile, any of which can be opened on the
pick screen. The pile for the view showing is highlighted; to start, its
label is drawn in the accent colour, which is easy to change once we've
seen it. Keepers isn't clickable yet.

On the pick screen, Return on a done group un-marks it, so it goes back
to being worked on and returns to the sort screen's grid.

Out of scope for now: a keepers view, ⌘Z, animation, and arrow keys on the
done view (clicks and Return only). No change to the keeps.json format.

## Layout

The piles leave `Sort/`: they now serve more than one screen, so they're
the shell's navigation, in `App/` as `FolderPiles`, and `FolderView` lays
them beside whichever screen is showing (not the pick screen) and owns
which view that is. The done view is a new folder, `Done/`, using
Grouping, Images, Folder, and Keys, like Sort and Pick, and never them.
Drawing a group as a pile moves into `Images/` (`PrintPile` learns the top
photo's shape when not given one) and `Pile`'s ordering into `Grouping/`,
so Sort and Done can both use them.

## Steps

Each step builds and passes the tests, then review and commit.

1. ✅ **Return toggles done.** `Grouping.markOpenGroupNotDone()`, tested; on
   the pick screen, Return on a done group calls it, and F works again
   once it's not done. Focus stays on the focused photo.
2. ✅ **Done groups and what's to go.** `Grouping` gives the done groups,
   latest first, opens any closed group directly (`open(_:)` becomes
   public), and gives the photos still to go, next up first. Tested.
3. ✅ **Share drawing a group as a pile.** `Pile` moves to `Grouping/`; the
   sort cell's collapsed stack becomes a `PrintPile`, which learns the top
   photo's shape when not given one. Check the sort grid by hand.
4. ✅ **Piles as navigation.** `FolderPiles` in `App/` with the to-go pile
   added, beside the screen in `FolderView`, which now owns the view
   showing. Clicking to go or set aside switches view (set aside shows an
   empty placeholder until step 5), and the current pile's label is
   highlighted. Check by hand.
5. ✅ **The done view.** `DoneScreen` in `Done/`: the done groups as piles,
   latest first, each with how many were kept, such as "2 of 7 kept".
   Click selects; double-click or Return opens on the pick screen, and
   Escape there comes back here. Check by hand, including un-marking a
   group and seeing it return to the sort screen.

# Plan: Dragging the keepers into Lightroom

## Goal

Get the keepers into Lightroom (the cloud version) without copying them
anywhere first. Dragging files from Finder onto Lightroom opens its import
screen with just those photos, from either its Local or Cloud tab, so
dragging the keepers pile out of Keeps should hand over exactly the same
thing: the keepers' files.

## Design

- **What's dragged.** The keepers of the done groups, one file each: the
  RAW where there is one, otherwise the JPEG (`PhotoItem.sourceURL`).
  Nothing is copied, moved, or written.
- **Where from.** The keepers pile in the sidebar. It isn't a section, so
  dragging is all it does. Dropping in Finder copies the files there, as
  any file drag would.
- **How.** SwiftUI's drag modifiers hand over one item, so an AppKit view
  over the pile starts the drag with one item per file, drawn as a pile of
  their thumbnails, which AppKit badges with the count.

Out of scope: the set-aside photos, JPEGs of RAW+JPEG pairs, and any
change to keeps.json.

## Steps

Each step builds and passes the tests, then review and commit.

1. ✅ **The keepers' files.** `Grouping.keeperFileURLs`: the keepers of the
   done groups as files, RAW preferred. Tested. (Dropped in step 2: the
   drag needs the photos, for their thumbnails, and `PhotoItem.sourceURL`
   already picks the RAW, tested.)
2. ✅ **Drag the pile.** `PhotoDragSource` in `App/` over the keepers pile
   in `FolderPiles`. Check by hand: drag onto Lightroom and into Finder.

# Plan: Review fixes for simplicity and clarity

## Goal

Work through a code review: stop an unreadable keeps.json from being
overwritten, then simplify the places where the same idea is spelled out
more than once, or where a reader has to hold an unstated rule in their
head.

## Steps

Each step builds and passes the tests, then review and commit.

1. ✅ **Never overwrite a keeps.json that can't be read.** `KeepsFile.restore()`
   returns nil only when there's no file, and throws when the file can't
   be read, isn't valid, or is in a format it doesn't know. `FolderView`
   shows the error and doesn't autosave that folder, so the file is left
   as it was. Tested.
2. ✅ **Name the open group's photos by photo index.** `PickArrangement` takes
   the group and the keepers and gives tile and pile photos as photo
   indices, so `PickScreen` stops converting to and from places in the
   group, and toggling a keeper no longer relies on every photo being a
   tile. Tested.
3. ✅ **Count a group's keepers in one place.** `Grouping.keptCount(in:)`, used
   by the pick screen's header and the done screen's labels. Tested.
4. ✅ **Tidy Grouping.** Order its members by what they're for, with MARK
   headers; a `Set.toggle` for boundaries and keepers; drop the
   unexplained local copies of `layout`; say "picking" rather than
   "narrowing", which isn't in the glossary.
5. ✅ **One selection highlight.** A shared modifier in `Images/` draws the
   highlight on the sort, pick, and done screens, hidden while the window
   isn't key. The done screen didn't hide it before. Check by hand.
6. ✅ **Share the duplicated constants.** One typical photo shape for blank
   paper and a group with no thumbnails yet; `KeeperBadge` moves to
   `Images/` so the keepers pile can use its colour; the sort screen's
   pile badge becomes a coloured `PileLabel`.
7. ✅ **Bring ImagePipeline up to date.** One helper for hearing that an
   item's image has loaded, used by `ThumbnailImage` and `FullSizeImage`;
   one method to finish a load in place of three closures; comments that
   match the four priority tiers; no abbreviated names; header comments
   on the helpers here, in `ImageCache`, and in `FolderScanner`.
8. ✅ **Simplify the folder's session and view.** `FolderSession` isn't
   observable, since its photos never change. `FolderView` hands a
   non-optional grouping to a subview, so it's unwrapped once.
9. ✅ **Comment nits.** Wrap comments at 80 columns, and call `PhotoItem`'s
   rule what it is: a struct's, not a class's.

# Plan: A keepers screen

## Goal

See the keepers so far, all together, and look at any of them full size,
without opening their groups one at a time.

## Design

- **A third section.** `FolderSection` gains `keepers`, titled "Keepers".
  Clicking the keepers pile in the sidebar selects it, and the pile sits on
  the highlight like the other two. Dragging the pile still hands over the
  keepers' files: `PhotoDragView` reports a press that ends without a drag
  as a click.
- **What it shows.** The keepers of the done groups
  (`Grouping.keepersOfDoneGroups`), in the same order as the pile: the
  latest group's first, and each group's in folder order. They're laid out
  as tiles like the pick screen's, using `TileLayout`, so a few keepers
  fill the window and many scroll. No keeper badges, since every photo
  here is a keeper.
- **Input.** Clicking a tile selects it. Arrow and h/j/k/l keys move the
  selection, as on the pick screen. Space or a double-click shows the
  selected photo full size, where left and right (and up and down) step
  through the keepers, and Space or Escape goes back to the tiles.
- **Full size.** `FullSizeImage` over the tiles, with the photo's place
  among the keepers, fading in and out rather than zooming from the tile.
- **When the keepers run out.** If a group is reopened and its keepers
  unmarked, so there are none left, the keepers pile disappears, and the
  window goes back to the sort screen, as it already does for the done
  screen.
- **Where it lives.** A new `Keepers/` folder, using Grouping, Images,
  Folder, and Keys like the other screens, and never Sort, Pick, or Done.
  So `FullSizeImage` and `TileLayout`, which know nothing about groups,
  move from `Pick/` to `Images/`, where the screens' shared pieces live.

Out of scope: changing keepers from this screen (that's still the pick
screen's job), opening a keeper's group from here, and zooming from the
tile, which would mean sharing PickScreen's zoom machinery.

## Steps

Each step builds and passes the tests, then review and commit.

1. ✅ **Share the full-size image and the tile layout.** Move
   `FullSizeImage` and `TileLayout` to `Images/`, and update the READMEs.
   No behaviour changes.
2. ✅ **The keepers screen.** `KeepersScreen` in `Keepers/`, with its README
   (added to the project's README exceptions), the `keepers` section, the
   clickable keepers pile, and falling back to the sort screen when the
   keepers run out. The section's fallback rule is pure and tested. Check
   by hand: click and drag the pile, move around, and view full size.
   Update CLAUDE.md's architecture, layering, and glossary.

# Plan: Measuring, then sharpening the tiles

## Goal

The pick and keepers screens' tiles look soft, because they scale up the
sort screen's 520-pixel thumbnails, often by two or three times. That's
the one problem known for sure. Otherwise image loading feels fast, even
flicking through full-size views, and memory isn't a concern: the app
may be memory hungry as long as it stays fast. So the aim is to sharpen
the tiles, and to add any other complexity (cache budgets, smaller
full-size images, different preloading) only when a measurement shows a
problem it would fix.

## What we know

- **The photos.** A Fuji X-T5, 40 MP (7728 × 5152), shooting both RAW
  and JPEG. A decoded original is about 160 MB.
- **RAF previews.** Each RAF embeds a 4416 × 2944 JPEG preview (about
  13 MP, about 52 MB decoded), which is what `ImageReader` reads for
  RAWs. It's big enough to show full screen, but not for 100% zoom.
- **100% zoom** is wanted later, for checking focus. It will need the
  original: the camera JPEG, or the RAW decoded in full. Nothing here
  should stand in its way.
- **No JPEG full-size bug.** It was suspected that for a JPEG with no
  RAW, `ImageReader.fullImage` returns the small thumbnail embedded in
  the file. The benchmark shows it decodes the whole 7728 × 5152 image.

## Design

### What to measure

- **Time to sharp.** From asking for an image (a step at full size, a
  group opening) to the good image being on screen, rather than the
  thumbnail standing in. The main measure.
- **Sharp straight away.** The share of steps whose image was already
  cached or preloaded.
- **Hitches.** Frames where the main thread stalls.
- **Memory over time.** Mainly to catch macOS squeezing the app, when
  NSCache would drop everything at once.

### How

- **Signposts.** `os_signpost` intervals in `ImagePipeline` for each
  read, labelled with the size asked for and the pixel size decoded, and
  split into time queued and time decoding. Events for cache hits,
  misses, and evictions (NSCache's delegate reports these). An interval
  in `FullSizeImage`, and later the tiles, from asking to sharp. They
  cost next to nothing, so they stay in, and Instruments shows them
  beside CPU, memory, and hangs.
- **A debug overlay.** Debug builds only: the app's memory footprint,
  what's cached at each size (count and megabytes), the hit rate, and
  the median and slowest time to sharp over the last 50 steps. The
  statistics are a small pure struct, tested.
- **A decode benchmark.** A script that runs `ImageReader`'s reads over
  sample photos and reports how long each takes: a RAF's preview in full
  and at tile size, a camera JPEG, a JPEG on its own, and a RAW decoded
  in full. The samples go in a folder that git ignores.

### Scenarios

Run the same way each time, so results compare across changes:

1. **Open a large folder cold.** How long until every thumbnail is
   cached, and the memory afterwards.
2. **Open a big group.** How long until every tile is sharp.
3. **Hold the right arrow at full size.** Key repeat steps at a steady
   rate. The share of steps sharp straight away, and time to sharp.
4. **Step at a normal pace,** about one photo a second.

### What good looks like

To be agreed with the baseline in hand, but roughly: normal stepping is
always sharp straight away, tiles are sharp within a quarter of a
second, and nothing hitches. A change is worth keeping when it moves one
of these.

### Sharper tiles

Tiles ask for an image sized to the tile in pixels (points times the
screen's scale), rounded up to one of a few fixed sizes, such as 1024,
1536, 2048, or 3072. The fixed sizes mean resizing the window or opening
another group doesn't start new reads for slightly different sizes, and
the pick and keepers screens share what's cached. The 520-pixel
thumbnail stands in until the larger image loads, as it already does at
full size. `ImageSize.thumbnail(maxPixelSize:)` already takes any size,
so the pipeline and cache need no new kind of size.

The sandbox stops Claude launching the app or Instruments, so the user
runs the scenarios and shares the overlay's numbers or a saved trace.
Claude can run the benchmark.

Out of scope until a measurement calls for it: cache budgets, limiting
the full-size view to the screen's size (the first traces called for it;
see below), changes to preloading, and
reading the camera JPEG of a RAW+JPEG pair for display. 100% zoom is a
later plan.

## Decode benchmark results

`Benchmarks/run-decode-benchmark` on 3 November 2026, on a 14-inch M1
MacBook Pro with 32 GB of memory running macOS 27.2, over four X-T5 RAFs
and two X-T5 JPEGs shot without RAW (there were no RAW+JPEG pairs to
hand). Medians of five runs, with the files in the disk cache. Read is
the background work; draw is the first draw into a bitmap of the same
size.

| Read | RAF: size | RAF: read | RAF: draw | JPEG: size | JPEG: read | JPEG: draw |
|---|---|---|---|---|---|---|
| Full size, as the app reads | 4416 × 2944 | 100–145 ms | 20 ms | 7728 × 5152 | 385 ms | 65 ms |
| Thumbnail, 520 px | 520 px | 40 ms | 0 ms | 520 px | 145 ms | 0 ms |
| Thumbnail, 2048 px | 2048 px | 75–160 ms | 4 ms | 2048 px | 250 ms | 4 ms |
| Whole image decoded | 7728 × 5152 | 2 ms | 280 ms | 7728 × 5152 | 265 ms | 95 ms |

What they show:

- **The JPEG full-size bug doesn't exist.** A JPEG's full-size read
  gives the whole image, so step 2 isn't needed.
- **A JPEG on its own costs about three or four times as much as a RAF**
  at every size, since it decodes the 40 MP original rather than the
  13 MP preview. Its full image also takes about 160 MB decoded, against
  52 MB. A folder of JPEGs is where loading will strain first.
- **The app's reads decode in the background.** Their draws are no
  slower than drawing an image known to be decoded already, so they
  don't leave decoding for the main thread. Whether showing a full image
  still stalls the main thread for a frame or two is for the signposts
  to tell.
- **Portrait RAFs read more slowly** (145 ms against about 100 ms at full
  size, and 160 ms against 80 ms at 2048 px), probably from rotating.
- **A RAW decoded in full takes about 280 ms**, all of it put off until
  the first draw. That's quick enough for 100% zoom, as long as the zoom
  decodes in the background.
- **Tiles at 2048 px** cost 75–160 ms a RAF and 250 ms a JPEG. A group of
  twenty RAFs is about 2 seconds of decoding, spread over the cores the
  pipeline uses.

## First traces

- **RAFs are smooth.** Opening a folder hangs the main thread for about
  180 ms, which isn't noticeable. After that, reads queue and run in the
  background, and once preloading starts, steps at full size are all
  sharp straight away.
- **JPEGs hang at full size.** Holding J through a group of JPEGs goes
  slowly at first, with main thread hangs on steps that were sharp
  straight away. Once the user gets ahead of preloading it speeds up,
  showing only thumbnails, and the hangs stop.
- **The cause is Core Animation preparing each image for display, on the
  main thread** (`CA::Render::prepare_image`, about 700 ms of 3 s of main
  thread time). For all 40 MP it copies the pixels (`memmove`), converts
  them to the display's colour space (`vLookupTable`, `vMatrixMultiply`),
  and adds an alpha channel, since ImageIO decodes JPEGs at 3 bytes a
  pixel. RAF previews go through the same thing at a third the size.

### Full-size images at screen size

The full-size view never shows more pixels than the screen has, so it
reads each image scaled to fit the largest screen rather than in full.
On the 14-inch MacBook Pro's 3024 × 1964 screen that's about a sixth of
a JPEG's pixels and half a RAF preview's, which shrinks the main thread
work, the decode, and the memory alike.

- `ImageSize.full` keeps its name and priorities, but means the image
  the full-size view shows, fitted to the largest screen, rather than
  the original file. 100% zoom will add a size for the original.
- The pipeline works out the size from the screens' pixel sizes each time
  it queues a full-size read, with a pure, tested function: the largest
  dimension of any screen. Images already cached when a bigger screen is
  plugged in stay at the old size until they're evicted, which is
  acceptable for something so rare.
- `ImageReader.fullImage` goes. The scaled read serves both sizes, and
  is renamed from `thumbnail` to `scaledImage`, since a 3000-pixel image
  isn't a thumbnail. The benchmark's full-size row reads at this Mac's
  screen size.

If hangs remain, the next thing to try is converting each image to the
display's format in the background, after decoding, so Core Animation
has nothing left to convert.

## Steps

Each step builds and passes the tests, then review and commit.

1. ✅ **Decode benchmark.** The script, and a git-ignored folder for
   sample photos. Run it on samples the user copies in, and record the
   results here. Confirm or rule out the JPEG full-size bug. (Results
   above: the bug doesn't exist.)
2. ~~**Fix JPEG full size,** if step 1 confirms the bug: decode a JPEG on
   its own in full.~~ Not needed: the benchmark shows a JPEG's full-size
   read decodes the whole image.
3. ✅ **Signposts** in `ImagePipeline` and `FullSizeImage`. Check by hand
   in Instruments. (`ImageSignposts`, under the com.notahat.Keeps
   subsystem's "Image loading" category, in the os_signpost instrument.
   The queue wait is a label on each read rather than an interval, since
   a read cancelled while queued would leave its interval open.)
4. ✅ **Debug overlay.** (Done first. `ImageLoadStats` and the tally in
   `ImageCache` are tested; Debug ▸ Show Image Stats, ⌥⌘I, shows it.
   Steps the user moves on from before they turn sharp are counted, so
   holding an arrow key doesn't flatter the figures.) The statistics
   struct, tested, and the overlay showing it with the memory footprint,
   in debug builds only.
5. **Full-size images at screen size** (see "First traces"). The size
   function, tested, then the pipeline reading `.full` at it, and the
   benchmark updated. The user repeats the J test on a JPEG group.
6. **Baseline.** The user runs the four scenarios. Record the results
   here and agree what good looks like.
7. **Sharper tiles.** The fixed sizes, a pure function, tested. Tiles on
   the pick and keepers screens load them, with the thumbnail standing
   in. Run scenario 2 again and compare.
8. **Review.** Look over the numbers for anything else worth doing, and
   plan it separately if so.
