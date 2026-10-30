# CLAUDE.md

## Architecture

The app is split into a stable rendering kit and a disposable workflow
module:

- `Keeps/Kit/` — stable ground: the image engine (ImagePipeline,
  ImageCache, ImageReader), folder scanning and session (FolderScanner,
  FolderSession), keeps.json and the generic persistence harness
  (KeepsFile, WorkflowPersistence), and dumb viewing surfaces
  (PhotoGridSurface, PhotoDetailSurface, ThumbnailImage). Surfaces
  interpret spatial keys into NavigationProposals and take cells/overlays
  via ViewBuilder closures; they know nothing about marks, filters, or any
  workflow concept.
- `Keeps/Workflows/<name>/` — everything one culling workflow owns: its
  state, screens, cell chrome, keymap, toolbar, dialogs, and persistence
  schema. Currently `GroupCull` (group by clicking between photos, collapse
  finished groups) is wired in; `SimpleCull` (flat pick/reject marks) is
  kept for comparison.
- `Keeps/KeepsApp.swift`, `ContentView.swift`, `FolderReference.swift`,
  `FolderPicker.swift`, `FolderCommands.swift`, `FolderWindows.swift`,
  `OpenFolderList.swift`, `RecentFolders.swift`, `AppLifecycle.swift`, and
  `WindowFramePersistence.swift`, plus `Keeps-Info.plist` at the project
  root — the shell: one window per folder (the window's value is a
  FolderReference carrying a security-scoped bookmark), File > Open Folder…
  and Open Recent (backed by the system's recent documents list, which
  regrants sandbox access), opening folders dropped on the Dock icon (the
  plist declares folders as a document type), reopening the folders that
  were open at quit (the app does this itself; system window restoration
  is disabled), keeping each window's size and position in its folder's
  keeps.json, and one wiring line in ContentView that hosts the workflow's
  root view.

**Dependency rule: Kit never imports from Workflows.** The kit must stay
free of workflow vocabulary (marks, filters, sort destinations).

To start a new workflow experiment: create `Keeps/Workflows/<name>/` with
its own state and root view, give its persisted state a distinct workflow
name (the keeps.json envelope ignores state written by other workflows),
and swap the one wiring line in ContentView.

## Build & Test

Build:
```bash
xcodebuild -project Keeps.xcodeproj -scheme Keeps -destination 'platform=macOS' build
```

Test:
```bash
xcodebuild test -project Keeps.xcodeproj -scheme Keeps -destination 'platform=macOS'
```

## Code Style

SwiftFormat runs automatically on every `.swift` edit via a PostToolUse hook — no need to run it manually.

## Testing

Tests use Swift Testing (`import Testing`, `@Test`, `#expect`) — not XCTest. Write all new tests to match this framework.

## Swift 6

The main target compiles under Swift 6 strict concurrency. All new code must satisfy the concurrency checker.

## Plans

Write implementation plans to `PLAN.md` at the project root and commit the plan before starting work.
