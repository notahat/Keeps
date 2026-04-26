# Keeps — Image Viewer MVP

## Goal

A macOS SwiftUI app for fast-viewing RAW/JPEG photo collections. First milestone is a high-performance image viewer only — no culling yet. The UI must always stay responsive: all image I/O on background threads, parallelised, with ahead-of-position preloading. Use `CGImageSource` APIs throughout; evaluate performance before considering alternatives.

UI should be minimal and distraction-free — no filenames, just photos.

---

## File Structure

```
Keeps/Keeps/
├── KeepsApp.swift              (modify: toolbar open-folder button)
├── ContentView.swift           (replace: top-level state + view routing)
├── Models/
│   ├── PhotoItem.swift         (new: value type — one photo or RAW+JPEG pair)
│   ├── FolderLibrary.swift     (new: @Observable — list, selection, view mode)
│   └── ImageLoader.swift       (new: actor, CGImageSource-based loading)
├── Views/
│   ├── GridView.swift          (new: LazyVGrid of thumbnails + keyboard nav)
│   ├── ThumbnailView.swift     (new: async thumbnail cell with placeholder)
│   └── SingleImageView.swift   (new: full-window fit image + preloading)
└── Utilities/
    └── ImageCache.swift        (new: NSCache<NSString, NSImage> wrapper)
```

---

## Data Model

### `PhotoItem` (struct)

- `id: UUID`
- `stem: String` — filename without extension, used for sorting only (not displayed)
- `rawURL: URL?` — .cr2 .cr3 .nef .arw .dng .raf .orf .rw2 etc.
- `jpegURL: URL?` — .jpg .jpeg
- `sourceURL: URL` computed — prefers rawURL (for embedded JPEG extraction), falls back to jpegURL

### `FolderLibrary` (@Observable class)

- `items: [PhotoItem]` — sorted by stem, case-insensitive
- `selectedIndex: Int?`
- `viewMode: ViewMode` — `.grid` | `.single`
- `openFolder(url:)` — scans directory, pairs files by stem, triggers thumbnail preload

RAW extensions: `cr2 cr3 nef arw dng raf orf rw2 rw1 3fr`
JPEG extensions: `jpg jpeg`

### `ImageLoader` (actor)

- `thumbnail(for: PhotoItem, maxPixelSize: Int) async -> NSImage?`
- `fullImage(for: PhotoItem) async -> NSImage?`

Both use `CGImageSource` with:
```
kCGImageSourceCreateThumbnailFromImageAlways: true
kCGImageSourceCreateThumbnailWithTransform: true
kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
```
Results stored in `ImageCache`.

### `ImageCache`

`NSCache<NSString, NSImage>` wrapper. NSCache handles memory pressure automatically.

---

## Views

### `ContentView`

- Holds `FolderLibrary` as `@State`
- Routes to `GridView` or `SingleImageView` on `library.viewMode`
- Toolbar: "Open Folder" button → `NSOpenPanel` (directories only)

### `GridView`

- `LazyVGrid` adaptive columns, ~200 pt fixed cell width
- Keyboard nav: `←→↑↓` and `h j k l`
- `Return` or double-click → `.single` view
- Focusable container with `onKeyPress`

### `ThumbnailView`

- Fixed square frame, grey placeholder while loading
- `Task` on appear to load thumbnail via `ImageLoader`; cancelled on disappear
- No filename labels

### `SingleImageView`

- Image scaled to fit window with `.scaledToFit()`
- `←` / `h`, `→` / `l`, `↑` / `k`, `↓` / `j` — navigate
- `Escape` → return to `.grid`
- On appear / index change: preload indices `N-2…N+4` via `TaskGroup`

---

## Preloading

Single-image view fires a `TaskGroup` for the window `[N-2, N+4]` on each navigation. Results land in `ImageCache`; subsequent navigation hits cache synchronously.

Grid thumbnails are demand-loaded by `LazyVGrid` via `onAppear` — no explicit scheduling needed.

---

## Incremental Build Plan

Each increment produces a working, buildable app and has passing tests before we review and commit.

### Increment 1 — Folder scanning & file pairing

**Delivers:** App opens a folder and displays a plain list of photo items (text only — stem names), correctly pairing RAW+JPEG files.

Files: `PhotoItem.swift`, `FolderLibrary.swift`, `ContentView.swift` (open-folder button + list)

**Tests:** `FolderLibraryTests` — scanning a directory with mixed RAW, JPEG, and paired files produces the correct `PhotoItem` array (count, pairing, sorting).

---

### Increment 2 — Grid view with async thumbnails

**Delivers:** Replace text list with `LazyVGrid`. Thumbnails load in the background via `CGImageSource`; grey placeholder shows while loading.

Files: `ImageLoader.swift`, `ImageCache.swift`, `GridView.swift`, `ThumbnailView.swift`

**Tests:** `ImageCacheTests` — store and retrieve entries; verify cache returns the same object.

---

### Increment 3 — Grid keyboard navigation

**Delivers:** Arrow keys and vi keys (`h j k l`) move selection in the grid. Selected cell is visually highlighted.

Files: Update `GridView.swift`

**Tests:** `GridNavigationTests` — test the index-calculation logic (move right, left, up, down, clamp at edges) as a pure function.

---

### Increment 4 — Single-image view

**Delivers:** `Return` or double-click on a grid item enters a full-window image view (fit to window). `←/→` and `h/l` navigate; `↑↓` and `j/k` also navigate linearly. `Esc` returns to grid at the same item.

Files: `SingleImageView.swift`, update `ContentView.swift`

**Tests:** No new logic to unit test; covered by manual verification.

---

### Increment 5 — Preloading in single-image view

**Delivers:** On each navigation, preload the window `[N-2, N+4]` in a `TaskGroup`. Rapid navigation through a large RAW folder should feel smooth.

Files: Update `SingleImageView.swift`

**Tests:** `PreloadWindowTests` — test the index-window calculation (clamping, edge cases) as a pure function.

---

## Testing Notes

- Test public logic only; skip SwiftUI views and image-loading internals.
- Use real temp-directory fixtures (not mocks) for filesystem tests.
- Each increment should have green tests before review + commit.

---

## Verification (end state)

1. Open a folder with mixed RAW and JPEG files.
2. Grid appears immediately; thumbnails load progressively without blocking UI.
3. RAW+JPEG pairs appear as single items; no filenames shown.
4. Arrow / vi keys navigate selection in the grid.
5. `Return` enters single-image view; image fits the window.
6. Rapid navigation shows cached images with minimal lag.
7. `Esc` returns to grid with same item selected.
8. Activity Monitor: main thread stays idle during thumbnail loading.

---

# Next: Pass-based review

## Context

Currently, marking a photo causes it to immediately disappear from the filtered view
(e.g. marking as picked while in "Unmarked" filter removes it instantly). The desired
workflow is to review photos in passes: mark freely, see badges accumulate, then
explicitly commit the pass — at which point the pass advances to only the
still-unmarked items.

No explicit "start pass" action is needed — you're always implicitly mid-pass.

## Model

A fifth filter tab — **"Pass"** — is added alongside the existing four. The existing
tabs (All / Picked / Rejected / Unmarked) remain purely global and computed live as
today, with no behavioral change. Only the "Pass" tab uses a snapshot.

The Pass tab shows a fixed snapshot of items (initially all items in the folder).
Marks accumulate visually with badges but don't remove items from the Pass view.
Committing advances the snapshot to the currently-unmarked items from the previous
snapshot and resets to the Pass tab.

## Changes

**`FolderLibrary`** (`Keeps/Keeps/Models/FolderLibrary.swift`)
- Add `FilterMode` case: `.pass`.
- Add `private(set) var passSnapshot: [PhotoItem]` — set on `openFolder` (all items
  initially) and on `advancePass()`.
- `filteredItems` computed property: for `.pass`, returns `passSnapshot`; for all
  other modes, computed live from `items` + `marks` as today.
- `setMark(_:for:)` unchanged — marks update live, and since `.pass` uses the stored
  snapshot, items stay visible.
- Add `func advancePass()`: sets `passSnapshot = items.filter { marks[$0.id] == nil }`,
  sets `filterMode = .pass`, clamps `selectedIndex`.
- Add computed `var passHasMarkedItems: Bool` for disabling the commit button.
- `openFolder(url:)` sets `passSnapshot = scanned items`, resets `filterMode` to `.all`.

**`ContentView`** (`Keeps/Keeps/ContentView.swift`)
- Add `.pass` tag to the filter `Picker`: `Text("Pass").tag(FolderLibrary.FilterMode.pass)`.
- Add a "Next Pass" toolbar button calling `library.advancePass()`, disabled when
  `!library.passHasMarkedItems`.

## What stays the same
- All views already use `filteredItems`; no changes needed to `GridView`,
  `ThumbnailView`, or `SingleImageView`.
- The four global filter tabs behave exactly as today.

## Verification
1. Open a folder. Switch to the Pass tab — all photos visible.
2. Mark several photos with `p` and `x`. Confirm they stay visible with badges.
3. Switch to "Picked" — all picks shown globally. Switch to "Unmarked" — globally
   unmarked. Switch back to "Pass" — full pass snapshot still intact.
4. Hit "Next Pass" — Pass view now shows only the previously-unmarked items.
5. Repeat; confirm picks/rejects from all passes visible in the global Picked/Rejected
   tabs.
6. Confirm "Next Pass" is disabled when nothing in the pass snapshot is marked.
