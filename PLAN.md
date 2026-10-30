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
  `SortScreen` into a small helper that both screens use.
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
- **Full-size view.** `PhotoDetailSurface`, given only the group's photos.
  It already steps with h and l and preloads neighbours.
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
    to go back, and overlays a badge and an "n / total" counter.
  - `SimpleCullWorkflow.swift`, `handleKey`: ignores presses with ⌘, ⌃, or ⌥
    held, so F doesn't catch ⌘F. The pick screen's keys need the same.
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

1. **Shared key handling.** Move the hjkl/arrow-to-direction code out of
   `SortScreen` into a helper both screens can use. No change in
   behaviour. Tested.
2. **Narrowing model.** Keepers and done groups in `Grouping`: toggling a
   keeper, marking a group done, opening a group (collapsing up to it),
   and finding the next closed group that isn't done. Tested.
3. **Even-grid layout.** The pure layout function in `Pick/`: column
   choice, centred last row, the minimum tile size, and j/k targets.
   Tested.
4. **Pick screen.** The tiles, aspect ratios from cached thumbnails, and
   the pick screen with its header, F, Return, and Escape, opened by
   double-click or Return from the sort screen. Tiles scale up the sort
   screen's existing thumbnails, so there's no new image loading and it's
   quick to try. First point where narrowing can be tried. Give sort cells
   the double-click as `onTapGesture(count: 2)` with the single click as a
   `simultaneousGesture(SpatialTapGesture())`: a plain single-tap gesture
   waits out the double-click timeout, which makes selection lag.
5. **Image sizes and caching.** Exploratory: `ThumbnailImage` taking its
   size, larger images for tiles, then trying the pick screen and the
   sort screen, profiling memory, and adjusting how sizes are loaded, cached, and
   reused, including the fallback for unknown aspect ratios. Tests are
   written once the shape settles.
6. **Full-size view.** Space toggles `PhotoDetailSurface` for the focused
   photo, with movement and F still working.
7. **Done status on collapsed groups.** Keepers on top of the pile, the checkmark and
   "2 of 7" badge, and dimming for groups with no keepers.
8. **Persistence.** Keepers and done groups in `SavedGrouping`, with old
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

1. **Move and rename.** Files into the folders above (the Xcode groups
   follow the file system, so `git mv` is enough), and the type renames
   from the table, with their tests (`GroupingTests`,
   `SavedGroupingTests`, `KeepsFileTests`) and `makeGrouping` in
   TestHelpers. `SavedGrouping.originalFormatName` replaces
   `workflowName`. Nothing merged yet.
2. **Specific saving.** `KeepsFile` saves and restores `SavedGrouping`
   only. Its tests move from the stub state to `SavedGrouping`.
3. **FolderView owns the grouping.** Merge `GroupCullRootView` into
   `FolderView`.
4. **One sort screen.** Merge `PhotoGridSurface` into `SortScreen`, reading
   the grouping directly. Remove `NavigationProposal` and
   `displayedItems`.
5. **Split out the scrolling.** Move the scroll behaviour from
   `SortScreen` into `GridScrolling`.
6. **Docs.** Rewrite the architecture section of `CLAUDE.md` for the new
   folders and layering, add the vocabulary above as a glossary, and
   update the keeps.json rule's test reference.
