# Keeps

## Code Formatting

Run `swiftformat` after making any Swift code changes. The `.swiftformat` config at the repo root sets Swift 6.

## Architecture Overview

Keeps is a macOS photo culling app. The user opens a folder of photos, marks them as picks/rejects across multiple passes, then imports the picks into Lightroom Cloud.

### Key Types

**`PhotoItem`** (`Models/PhotoItem.swift`) — one photo or matched RAW+JPEG pair. Identified
in memory by `UUID id`, and on disk by `stem` (filename without extension, e.g. `IMG_001`).
At least one of `rawURL`/`jpegURL` is always non-nil.

**`FolderLibrary`** (`Models/FolderLibrary.swift`) — `@Observable` main state manager. Owns
`items: [PhotoItem]`, `passes: [Pass]`, `currentPassIndex`, `selectedItemID`, `viewMode`,
`filterMode`. A `Pass` is a `struct` with `picks: Set<UUID>` and `rejects: Set<UUID>`.

**`Mark`** — `enum { case pick, reject }`. `nil` means unmarked.

**`LibraryState`** (`Models/LibraryState.swift`) — `Codable` on-disk representation. Stores
passes as `[String]` arrays of stems (not UUIDs) so state survives folder moves.

**`LibraryPersistence`** (`Models/LibraryPersistence.swift`) — reads/writes `keeps.json` in
the open folder. Auto-saves via `withObservationTracking` whenever `library.passes` changes.
Translates between stems (on disk) and UUIDs (in memory).

**`ImagePipeline`** (`Models/ImagePipeline.swift`) — singleton async image loader with four
priority tiers (veryHigh/high/low/veryLow). Posts `imageLoadedNotification` when done.

**`ImageReader`** (`Models/ImageReader.swift`) — pure functions for reading RAW previews and
JPEGs. `ImageCache` wraps `NSCache`.

### Pass Architecture

A photo is visible in pass N if it is not marked (pick or reject) in any earlier pass. This
allows progressive culling: mark obvious rejects in pass 0, then work through unmarked photos
in pass 1, etc.

### Persistence

`keeps.json` is a runtime file written by the app into each opened photo folder — it is not
part of the source tree. Format:

```json
{
  "passes": [
    { "picks": ["IMG_001", "IMG_003"], "rejects": ["IMG_002"] }
  ]
}
```

Stems (not UUIDs) are used so state survives folder moves. The file is created on first mark
and auto-saved on every subsequent change.

### File Scanning

RAW extensions: `cr2, cr3, nef, arw, dng, raf, orf, rw2, rw1, 3fr`. JPEG: `jpg, jpeg`.
Files are paired by stem, sorted by file creation date.

### Key Source Files

| File | Purpose |
|------|---------|
| `Models/PhotoItem.swift` | Photo data model |
| `Models/FolderLibrary.swift` | Main state (folder, passes, marks, filtering) |
| `Models/LibraryState.swift` | Codable on-disk state |
| `Models/LibraryPersistence.swift` | reads/writes `keeps.json`, UUID ↔ stem bridge |
| `Models/ImagePipeline.swift` | Async image loader with priority queue |
| `Models/ImageReader.swift` | Pure RAW preview extraction and JPEG decode |
| `ContentView.swift` | Root view, folder selection, security-scoped sandbox access |
| `Views/GridView.swift` | Thumbnail grid with keyboard nav |
| `Views/SingleImageView.swift` | Full-screen single photo view |
| `Views/PassSidebarView.swift` | Pass list and "Start Next Pass" |
| `Views/PhotoCommands.swift` | Menu commands: Pick (f), Reject (s), Unmark (d) |
