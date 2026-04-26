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

## Testing

Build tests as features are added. Focus on logic that's worth unit testing:
- File pairing logic in `FolderLibrary` (correct grouping of RAW+JPEG by stem)
- `ImageCache` (eviction behaviour if we add custom logic)
- Any sorting/filtering logic added later

Avoid testing SwiftUI views or image-loading internals directly.

---

## Verification

1. Open a folder with mixed RAW and JPEG files.
2. Grid appears immediately; thumbnails load progressively without blocking UI.
3. RAW+JPEG pairs appear as single items; no filenames shown.
4. Arrow / vi keys navigate selection in the grid.
5. `Return` enters single-image view; image fits the window.
6. Rapid navigation shows cached images with minimal lag.
7. `Esc` returns to grid with same item selected.
8. Activity Monitor: main thread stays idle during thumbnail loading.
