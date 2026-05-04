# Plan: Breaking up FolderLibrary

## Goal

`FolderLibrary` currently owns folder scanning, the pass/mark model, photo
groups, filtering, selection, view mode, and save-error reporting. Extract the
most self-contained pieces into their own types so `FolderLibrary` becomes a
thinner `@Observable` orchestrator that wires the sub-stores together for the
UI. Pure refactor — no behavior changes.

## Target shape

After all steps are done, `FolderLibrary` keeps:

- `folderURL`, `folderError`, `saveError`
- selection state: `selectedItemID`, `rangeAnchorID`, computed `selectedIndex`
  / `selectionRange` / `selectedRangeItems`, plus `selectItem` /
  `extendSelection`
- `viewMode`, `filterMode`, `filteredItems`, `applyFilter`,
  `updateFilteredItems`
- `lastMarkEvent` (UI observation hook)
- orchestration actions that span sub-stores: `applyMarkAndAdvance`,
  `focusSelectedItemGroup`, `ungroupSelectedItem`, `rejectRestOfGroup`,
  `createGroupFromSelection`, `close`, `openFolder`

Three new types absorb the rest:

- `FolderScanner` — pure file-system → `[PhotoItem]`
- `PassStore` — passes, current pass index, marks, pass stats, sort plan
- `GroupStore` — groups data plus pure CRUD/lookups

## Steps

### Step 1: Extract FolderScanner

**Files:** `Keeps/Models/FolderScanner.swift` (new),
`Keeps/Models/FolderLibrary.swift`,
`KeepsTests/FolderScannerTests.swift` (new)

- Create `FolderScanner` as an enum with static methods (no instance state).
- Move `scanFolder`, `pairFilesByType`, `buildSortedItems`, `creationDate`
  into it. Expose a single entry point
  `FolderScanner.scan(url:) throws -> [PhotoItem]`.
- `FolderLibrary.openFolder` calls `FolderScanner.scan(url:)`.
- Tests cover: empty folder, RAW-only, JPEG-only, paired RAW+JPEG, sort
  order by capture date, hidden files skipped, unsupported extensions
  ignored. Use a temp directory.
- Verify build + tests, review, commit.

### Step 2: Extract PassStore

**Files:** `Keeps/Models/PassStore.swift` (new),
`Keeps/Models/FolderLibrary.swift`,
`KeepsTests/PassStoreTests.swift` (new),
`KeepsTests/FolderLibraryTests.swift`

- Create `PassStore`. Move into it: `Pass`, `PassStats`, `Mark`, `passes`,
  `currentPassIndex`, `setMark`, `mark(for:)`, `cumulativeMark`,
  `sortPlan(items:)`, `currentPassPhotoIDs(items:)`, `stats(for:items:)`,
  `startNextPass`, `selectPass`, `initializeFresh`, `applyRestored`,
  `canStartNextPass`. Methods that needed `items` now take it as a parameter
  (the store itself doesn't own the universe of photos).
- Decide value type vs class based on what views observe. If the UI reads
  `passes` / `currentPassIndex` directly through `FolderLibrary`'s
  `@Observable` tracking, a struct works. If views need to observe the store
  directly, make it `@Observable` and have `FolderLibrary` hold it as `let`.
- `FolderLibrary` exposes thin pass-throughs only where existing call sites
  read these fields; otherwise rewrite call sites to use `passStore.`.
  `setMark(_:for:)` on `FolderLibrary` becomes: delegate to `passStore`,
  then call `updateFilteredItems()` when `filterMode != .all`.
  `applyMarkAndAdvance` stays on `FolderLibrary` (spans selection + marks +
  filter).
- `LibraryPersistence` restore hooks forward into `passStore`.
- Move existing pass/mark tests to `PassStoreTests` where they apply to the
  store in isolation; keep orchestration tests
  (e.g. `applyMarkAndAdvance` selection advance, filter recompute on mark)
  in `FolderLibraryTests`.
- Verify, review, commit.

### Step 3: Extract GroupStore

**Files:** `Keeps/Models/GroupStore.swift` (new),
`Keeps/Models/FolderLibrary.swift`,
`KeepsTests/GroupStoreTests.swift` (new),
`KeepsTests/FolderLibraryTests.swift`

- Create `GroupStore`. Move into it: `PhotoGroup`, `groupColors`, `groups`,
  `color(for id: UUID) -> Color?`, `group(containing id: UUID) ->
  PhotoGroup?`, `removeGroup(containing:)`, `addGroup(itemIDs:) ->
  PhotoGroup`, `applyRestored(_:)`, plus the private `nextColorIndex`
  helper.
- `FolderLibrary` keeps the selection-aware orchestrators
  (`focusSelectedItemGroup`, `ungroupSelectedItem`, `rejectRestOfGroup`,
  `createGroupFromSelection`) and the filter-aware queries
  (`isGroupFocused`, `focusedGroupColor`, `selectedItemIsGrouped`), each
  rewritten to call into `groupStore`.
- `LibraryPersistence` restore hook forwards into `groupStore`.
- `GroupStoreTests` covers color-index selection (least-used wins), add,
  remove, membership lookup, restore. Orchestration tests stay in
  `FolderLibraryTests`.
- Verify, review, commit.

### Step 4: Tidy FolderLibrary

**Files:** `Keeps/Models/FolderLibrary.swift`

- Have `close()` reset sub-stores via dedicated `reset()` methods rather
  than re-assigning their fields directly.
- Re-read the class top-to-bottom; update the class doc comment to reflect
  the narrower scope.
- If a further split (e.g. a `Selection` value type) feels worthwhile at
  this point, decide then — not now.
- Verify, review, commit.

## Out of scope

- View-mode and save-error fields are trivial; leave them on
  `FolderLibrary`.
- No changes to `LibraryPersistence`, `ImagePipeline`, or any view code
  beyond what the extractions force.
- No new features or behavior changes.
