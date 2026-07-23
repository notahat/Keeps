# Plan: Decouple the culling workflow from the rendering kit

## Goal

Split the app into a stable **rendering kit** (image engine, dumb viewing
surfaces, folder session, persistence harness) and a disposable **workflow
module** that owns everything about how culling works. Future workflow
experiments replace the module (on branches) without touching the kit.

Workflow #1 is a *reduced* port of today's behaviour: flat pick/reject/unmark
marks in a grid + single-image view, with the all/picked/rejected/unmarked
filter and the sort-into-folders endpoint. Passes and groups are deleted
(git history is the archive if a future experiment wants them back).

## Design decisions (from the design interview)

- **One workflow at a time, in code.** No workflow protocol or registry; the
  seam is clean factoring plus one wiring line in the shell.
- **Kit never imports from Workflows.** The directory boundary is the
  dependency rule: `Keeps/Kit/` is stable ground, `Keeps/Workflows/<name>/`
  is experiment territory.
- **Full cell injection.** Grid and detail surfaces take ViewBuilder
  closures; the workflow composes kit-provided image views plus its own
  chrome (badges, bars, counters).
- **Geometry-aware proposals.** Surfaces interpret spatial keys only (the
  grid turns arrows/hjkl into a proposed target index using its column
  math) and hand proposals to the workflow, which owns all policy. Every
  other key forwards raw to the workflow's keymap.
- **Kit harness + workflow schema for persistence.** The kit keeps
  auto-save, error surfacing, and the file plumbing; the workflow supplies
  its own Codable state. The file embeds the workflow's name so stale state
  from a different experiment is detected rather than mis-decoded.
- **Shell = folder only.** The stable shell owns open/restore folder,
  security bookmarks, and hosting the workflow's root view. Sidebar,
  toolbar, dialogs, and marking shortcuts are workflow territory; the
  marking shortcuts move from the Photo menu into the workflow keymap.
- **PhotoSorter is workflow-owned.** Picked/Rejected/Undecided is
  SimpleCull vocabulary, not kit vocabulary.

**Data-loss caveat:** existing `keeps.json` files (pass-based schema) will
not restore into the new format — the envelope check treats them as absent
and starts fresh. Finish any in-flight culls before running the new build,
or accept re-marking.

## Target shape

```
Keeps/
  KeepsApp.swift            — app entry; registers FolderCommands
  ContentView.swift         — shell: open/restore folder, bookmarks, hosts
                              the workflow's root view (the one wiring line)
  Kit/
    PhotoItem.swift
    FolderScanner.swift
    FolderSession.swift         (new)
    ImagePipeline.swift
    ImageCache.swift
    ImageReader.swift
    ImageSize.swift
    WorkflowPersistence.swift   (new)
    ThumbnailImage.swift        (new, extracted from ThumbnailView)
    PhotoGridSurface.swift      (new, extracted from GridView)
    PhotoDetailSurface.swift    (new, extracted from SingleImageView)
    NavigationProposal.swift    (new)
    KeyAwareView.swift
    KeyCode.swift
    LoadGraphView.swift
  Workflows/
    SimpleCull/
      SimpleCullWorkflow.swift  (from FolderLibrary: marks, selection,
                                 filter, view mode, keymap)
      MarkStore.swift           (new, replaces PassStore)
      SimpleCullState.swift     (new persistence schema, replaces
                                 LibraryState)
      SimpleCullRootView.swift  (toolbar, filter picker, dialogs, routing,
                                 persistence wiring)
      SimpleCullGridScreen.swift    (from GridView)
      SimpleCullDetailScreen.swift  (from SingleImageView)
      SimpleCullCell.swift          (from ThumbnailView)
      MarkIcon.swift, MarkButton.swift
      PhotoSorter.swift
```

### Key kit APIs

```swift
/// Owns one open photo folder: security-scoped access, the scan, and the
/// resulting items. Access begins on init and ends on deinit.
@Observable @MainActor final class FolderSession {
    let folderURL: URL
    private(set) var items: [PhotoItem]
    init(folderURL: URL) throws   // starts scope, scans; throws scan errors
}

/// Saves and restores a workflow's Codable state to keeps.json in the photo
/// folder. The JSON envelope is { "workflow": <name>, "state": { ... } };
/// restore returns nil when the file is missing, unreadable, or written by
/// a different workflow.
final class WorkflowPersistence<State: Codable> {
    init(folderURL: URL, workflowName: String)
    func restore() -> State?
    func save(_ state: State) throws
    /// Re-saves whenever the observable state touched by `read` changes.
    @MainActor func startObserving(
        read: @escaping () -> Void,
        snapshot: @escaping () -> State,
        onSaveError: @escaping (Error) -> Void
    )
    func stop()
}

/// A spatial selection move computed by a surface from a navigation key or
/// click. The surface owns geometry; the workflow owns what happens.
struct NavigationProposal {
    let targetIndex: Int
    let extendsRange: Bool   // shift was held
}

/// Square thumbnail cell body: cached image or placeholder. Owns the
/// request/deprioritize lifecycle and the pixel-size constant.
struct ThumbnailImage: View {
    let item: PhotoItem
    static let imageSize: ImageSize
}

/// Lazy scrolling grid over items. Owns column math, scroll-to-selection,
/// and spatial key interpretation. Knows nothing about marks or filters.
struct PhotoGridSurface<Cell: View>: View {
    var items: [PhotoItem]
    var selectedIndex: Int?
    var onNavigate: (NavigationProposal) -> Void
    var onKeyDown: (NSEvent) -> Bool          // non-spatial keys, raw
    var onTap: (_ index: Int, _ extendsRange: Bool) -> Void
    var onDoubleTap: (_ index: Int) -> Void
    @ViewBuilder var cell: (_ item: PhotoItem, _ index: Int) -> Cell
}

/// Full-window view of items[selectedIndex]. Owns full-size loading, the
/// preload window (4 ahead / 2 behind), and linear key interpretation
/// (left/right/hjkl → ±1 proposals). Overlay closure carries all chrome.
struct PhotoDetailSurface<Overlay: View>: View {
    var items: [PhotoItem]
    var selectedIndex: Int?
    var onNavigate: (NavigationProposal) -> Void
    var onKeyDown: (NSEvent) -> Bool
    @ViewBuilder var overlay: (_ item: PhotoItem) -> Overlay
}
```

### Key workflow APIs

```swift
/// Flat per-photo marks. No passes: one mark per photo, last write wins.
struct MarkStore {
    enum Mark: String, Codable { case pick, reject }
    func mark(for id: UUID) -> Mark?
    mutating func setMark(_ mark: Mark?, for id: UUID)
    func sortPlan(items: [PhotoItem]) -> [Mark?: [PhotoItem]]
    mutating func applyRestored(marks: [UUID: Mark])
}

/// Persistence schema for SimpleCull, keyed by photo stem so state
/// survives folder moves. Workflow name: "simple-cull".
struct SimpleCullState: Codable {
    var picks: [String]
    var rejects: [String]
}
```

`SimpleCullWorkflow` (@Observable, init takes `items: [PhotoItem]`) keeps
what remains of `FolderLibrary`: selection (`selectedItemID`,
`rangeAnchorID`, `selectedIndex`, `selectionRange`, `selectItem`,
`extendSelection`), `filterMode` + `filteredItems`, `viewMode`,
`applyMarkAndAdvance` + `lastMarkEvent`, `saveError` reporting, and a
`handleKey(_ event: NSEvent) -> Bool` keymap for f/s/d.

## Steps

Each step ends with build + tests green, review, and a commit.

### Step 1: Move engine and input files into Kit/

**Files:** `git mv` into `Keeps/Kit/`: `ImagePipeline`, `ImageCache`,
`ImageReader`, `ImageSize`, `PhotoItem`, `FolderScanner` (from `Models/`),
`LoadGraphView`, `KeyAwareView`, `KeyCode` (from `Views/`).

- Pure file moves, no code changes. The Xcode project uses
  filesystem-synchronized groups, so no pbxproj edits are needed.
- Verify, review, commit.

### Step 2: Delete groups

**Files:** delete `Keeps/Models/GroupStore.swift`,
`KeepsTests/GroupStoreTests.swift`, `KeepsTests/GroupingTests.swift`,
`KeepsTests/RejectRestOfGroupTests.swift`. Modify `FolderLibrary`,
`ContentView`, `PhotoCommands`, `ThumbnailView`, `SingleImageView`,
`GridView`, `LibraryPersistence`, `LibraryState`, `FilterTests`,
`FolderLibraryTests`, `LibraryPersistenceTests`.

- Remove from `FolderLibrary`: `groupStore`, `groups`, `groupColor(for:)`,
  `selectedItemIsGrouped`, `isGroupFocused`, `focusedGroupColor`,
  `focusSelectedItemGroup`, `ungroupSelectedItem`, `rejectRestOfGroup`,
  `createGroupFromSelection`, `applyRestoredGroups`, and the
  `.group` case of `FilterMode`.
- Remove group commands from `PhotoCommands`, the group segment from
  `ContentView`'s filter picker, `groupColor` from `ThumbnailView` and the
  group bar from `SingleImageView`.
- Drop `groups` from `LibraryState` (and its custom decoder) and from
  `LibraryPersistence.save`/`restore`.
- Update the tests the compiler flags; delete the three group test files.
- Verify, review, commit.

### Step 3: Extract FolderSession

**Files:** create `Keeps/Kit/FolderSession.swift`,
`KeepsTests/FolderSessionTests.swift`. Modify `FolderLibrary`,
`ContentView`, `LibraryPersistence`, `TestHelpers`, `FolderLibraryTests`.

- TDD `FolderSession`: init scans via `FolderScanner` and holds `items`;
  scan failure throws; deinit ends security-scoped access. Tests: items
  populated from a temp folder, throwing on an unreadable URL. (Security
  scope is untestable outside the sandbox; keep that code trivial.)
- `FolderLibrary` loses `folderURL`, `folderError`, `openFolder`, and item
  scanning; it gains `init(items: [PhotoItem])` (plus updated `close`
  semantics — the shell now just drops the session and library).
- `ContentView.startSession` creates the session, then the library from
  `session.items`; the folder-error state reads from the thrown error.
- `LibraryPersistence` stops managing the security scope (session owns it)
  but keeps everything else for now.
- Update `makeLibrary` in `TestHelpers` to build items directly.
- Verify, review, commit.

### Step 4: Add the WorkflowPersistence harness

**Files:** create `Keeps/Kit/WorkflowPersistence.swift`,
`KeepsTests/WorkflowPersistenceTests.swift`.

- TDD the harness per the API sketch above. Envelope encode/decode with
  the workflow name; `restore` returns nil for a missing file, undecodable
  JSON, or a mismatched workflow name. `startObserving` re-arms
  `withObservationTracking` after each save, reports failures through
  `onSaveError`, and `stop()` halts it (mirrors today's
  `LibraryPersistence` observation loop).
- Not wired to anything yet — the old persistence keeps running.
- Tests: round-trip save/restore, nil on missing file, nil on wrong
  workflow name, nil on garbage JSON, save error reported through the
  callback, observation-triggered re-save.
- Verify, review, commit.

### Step 5: Replace passes with MarkStore and switch persistence

**Files:** create `Keeps/Workflows/SimpleCull/MarkStore.swift`,
`Keeps/Workflows/SimpleCull/SimpleCullState.swift`,
`KeepsTests/MarkStoreTests.swift`. Delete `PassStore.swift`,
`PassSidebarView.swift`, `LibraryPersistence.swift`, `LibraryState.swift`,
`PassStoreTests.swift`, `PassTests.swift`, `CumulativeMarkTests.swift`,
`LibraryPersistenceTests.swift`. Modify `FolderLibrary`, `ContentView`,
`MarkIcon`, `ThumbnailView`, `SingleImageView`, `PhotoSorter`, remaining
tests.

- TDD `MarkStore` per the sketch (set/clear/replace marks, sort plan).
- `FolderLibrary` swaps `PassStore` for `MarkStore`; `updateFilteredItems`
  reduces to filtering by mark; delete `cumulativeMark`, `stats`,
  `startNextPass`, `selectPass`, `canStartNextPass`, `passes`,
  `initializeFreshPasses`, `applyRestoredPasses`. Add stem-map translation
  to/from `SimpleCullState` (two small pure functions on the library:
  `snapshotState() -> SimpleCullState`, `applyRestored(state:)`).
- `ContentView` drops the `NavigationSplitView` sidebar (detail content
  becomes the whole window) and wires
  `WorkflowPersistence<SimpleCullState>` (workflow name "simple-cull") in
  `startSession`, including restore, observation, and save-error
  reporting.
- `PassStore.Mark` references across views and `PhotoSorter` become
  `MarkStore.Mark`.
- Migrate still-valid pass-store test cases (mark set/clear/exclusivity,
  sort plan) into `MarkStoreTests`; add a round-trip test for
  `snapshotState`/`applyRestored`.
- Verify, review, commit.

### Step 6: Extract ThumbnailImage; cell becomes workflow-owned

**Files:** create `Keeps/Kit/ThumbnailImage.swift`,
`Keeps/Workflows/SimpleCull/SimpleCullCell.swift` (from `ThumbnailView`).
Move `MarkIcon.swift` to `Keeps/Workflows/SimpleCull/`. Delete
`Keeps/Views/ThumbnailView.swift`.

- `ThumbnailImage`: the image-or-placeholder square with the
  request/deprioritize/notification lifecycle and the
  `displaySize`/`pixelSize`/`imageSize` constants. No selection, marks, or
  colors.
- `SimpleCullCell`: composes `ThumbnailImage` plus selection stroke,
  range-highlight fill, and `MarkBadge` overlay (`MarkBadge` moves here).
- `ContentView`'s prefetch call switches to `ThumbnailImage.imageSize`.
- Verify, review, commit.

### Step 7: Extract PhotoGridSurface

**Files:** create `Keeps/Kit/PhotoGridSurface.swift`,
`Keeps/Kit/NavigationProposal.swift`,
`Keeps/Workflows/SimpleCull/SimpleCullGridScreen.swift` (from `GridView`).
Delete `Keeps/Views/GridView.swift`.

- `PhotoGridSurface` per the sketch: lazy grid, column math, scroll-to on
  selection change, first-responder reclaim on tap, arrows/hjkl (+shift) →
  `NavigationProposal`, everything else → `onKeyDown`.
- `SimpleCullGridScreen` supplies the cell closure and policy: proposals →
  `selectItem`/`extendSelection`, double-tap and Return → single view,
  other keys → `workflow.handleKey` (which handles f/s/d marking — added
  here or in Step 9, whichever compiles cleanly; menu shortcuts still work
  meanwhile).
- Verify, review, commit.

### Step 8: Extract PhotoDetailSurface

**Files:** create `Keeps/Kit/PhotoDetailSurface.swift`,
`Keeps/Workflows/SimpleCull/SimpleCullDetailScreen.swift` (from
`SingleImageView`). Delete `Keeps/Views/SingleImageView.swift`.

- `PhotoDetailSurface` per the sketch: full-size load + preload window +
  deprioritize, loading placeholder with stem, linear key interpretation.
- `SimpleCullDetailScreen` supplies the overlay closure (mark badge,
  position counter, mark-flash feedback driven by `lastMarkEvent`) and
  policy: proposals → `selectItem`, Esc → grid via `onKeyDown`.
- Verify, review, commit.

### Step 9: Split shell from workflow root

**Files:** create `Keeps/Workflows/SimpleCull/SimpleCullRootView.swift`.
Rename/move `FolderLibrary.swift` →
`Keeps/Workflows/SimpleCull/SimpleCullWorkflow.swift`. Move
`MarkButton.swift`, `PhotoSorter.swift` into `Keeps/Workflows/SimpleCull/`.
Delete `Keeps/Views/PhotoCommands.swift`. Modify `ContentView`,
`KeepsApp`, `FolderCommands`, `TestHelpers`, tests.

- Rename `FolderLibrary` → `SimpleCullWorkflow`; add `handleKey` (f/s/d →
  `applyMarkAndAdvance`) if not done in Step 7.
- `SimpleCullRootView(session:)` owns: the workflow + persistence objects,
  grid/single routing on `viewMode`, the toolbar (filter picker, photo
  count + `LoadGraphView`, mark buttons, a Sort Photos button), the sort
  dialogs and save-error alert, and the sort execution via `PhotoSorter`.
- `ContentView` slims to the shell: empty/error states, open/restore
  folder, bookmark saving, and
  `SimpleCullRootView(session: session).id(session.folderURL)` — the
  single line an experiment replaces.
- Delete the Photo menu; `FolderCommands` keeps Open Folder (the sort menu
  item moves into the workflow's toolbar).
- Rename test helper `makeLibrary` → `makeWorkflow`; compiler-led updates.
- Verify, review, commit.

### Step 10: Tidy and document the boundary

**Files:** `CLAUDE.md`, doc comments across `Keeps/Kit/` and
`Keeps/Workflows/SimpleCull/`.

- Add an Architecture section to `CLAUDE.md`: the Kit/Workflows dependency
  rule (Kit never imports from Workflows), what belongs where, and how to
  start a new workflow experiment (copy or replace `Workflows/<name>/`,
  update the one wiring line in `ContentView`, pick a new workflow name
  for persistence).
- Re-read kit and workflow files top to bottom; fix stale doc comments.
- Verify, review, commit.

## Out of scope

- No new workflow experiments in this plan — it ends with today's reduced
  behaviour on the new architecture.
- No framework/package split; the directory boundary is the rule.
- No menu-command injection seam; promoted workflows can add menus later.
- No changes to `ImagePipeline` internals, `ImageReader`, or scan/pairing
  logic.
