# Keeps

## The UUID/stem duality

Photos have two identifiers:

- **UUID** (`id`) — used everywhere in memory.
- **stem** — the filename without extension (e.g. `IMG_001`), used in
  `keeps.json` on disk.

Stems are used for persistence so that saved state survives folder moves.
Whenever you touch code that crosses the memory/disk boundary, make sure you're
translating between them. `LibraryPersistence` owns this translation.

## Concurrency

The image pipeline uses `OperationQueue` and `NotificationCenter` — not
`async/await` or Swift actors. `ImagePipeline` is `@MainActor` and posts
`imageLoadedNotification` when a load completes. If you're adding image-loading
code, follow this pattern rather than reaching for Swift concurrency.
