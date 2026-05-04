# Keeps

## Concurrency

The image pipeline uses `OperationQueue` and `NotificationCenter` — not
`async/await` or Swift actors. `ImagePipeline` is `@MainActor` and posts
`imageLoadedNotification` when a load completes. If you're adding image-loading
code, follow this pattern rather than reaching for Swift concurrency.
