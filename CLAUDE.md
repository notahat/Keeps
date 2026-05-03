# Keeps

## The UUID/stem duality

Photos have two identifiers:

- **UUID** (`id`) — used everywhere in memory.
- **stem** — the filename without extension (e.g. `IMG_001`), used in
  `keeps.json` on disk.

Stems are used for persistence so that saved state survives folder moves.
Whenever you touch code that crosses the memory/disk boundary, make sure you're
translating between them. `LibraryPersistence` owns this translation.

## Pass visibility

A photo is visible in pass N only if it has not been marked (pick or reject) in
any earlier pass. `FolderLibrary.updateFilteredItems()` enforces this rule — be
careful when modifying filtering logic.

## Groups

Groups let the user associate related shots (e.g. a burst sequence) so they can
be culled together. Groups interact with pass visibility: focusing a group shows
only that group's photos that are visible in the current pass.

## Concurrency

The image pipeline uses `OperationQueue` and `NotificationCenter` — not
`async/await` or Swift actors. `ImagePipeline` is `@MainActor` and posts
`imageLoadedNotification` when a load completes. If you're adding image-loading
code, follow this pattern rather than reaching for Swift concurrency.

## Auto-save

`LibraryPersistence` uses `withObservationTracking` to watch `FolderLibrary`
state and write `keeps.json` automatically on every change. If you add new state
that needs persisting, add it to `LibraryState` and `LibraryPersistence` — the
observation tracking picks it up automatically.
