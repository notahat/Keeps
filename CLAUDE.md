# CLAUDE.md

## Architecture

The app is split into a stable rendering kit and a disposable workflow
module:

- `Keeps/Kit/` — stable ground: the image engine (ImagePipeline,
  ImageCache, ImageReader), folder scanning and session (FolderScanner,
  FolderSession), keeps.json and the generic persistence harness
  (WorkflowPersistence), and dumb viewing surfaces
  (PhotoGridSurface, PhotoDetailSurface, ThumbnailImage). Surfaces
  interpret spatial keys into NavigationProposals and take cells/overlays
  via ViewBuilder closures; they know nothing about marks, filters, or any
  workflow concept.
- `Keeps/Workflows/<name>/` — everything one culling workflow owns: its
  state, screens, cell chrome, keymap, toolbar, dialogs, and persistence
  schema. Currently `GroupCull` (group by clicking between photos, collapse
  finished groups) is wired in; `SimpleCull` (flat pick/reject marks) is
  kept for comparison.
- `Keeps/main.swift`, `AppDelegate.swift`, `MainMenu.swift`,
  `FolderDocumentController.swift`, `FolderDocument.swift`,
  `FolderWindowController.swift`, and `FolderView.swift`, plus
  `Keeps-Info.plist` at the project root — the shell, built on AppKit's
  document architecture. Each open folder is a `FolderDocument` (the plist
  declares folders as a document type with that class), so AppKit provides
  Open, Open Recent, opening folders dropped on the Dock icon, bringing an
  open folder's window forward, reopening folders at launch
  (`NSQuitAlwaysKeepsWindows` is registered so this happens whatever the
  system setting), sandbox access to them, including after a relaunch, and
  saving each window's frame (in the app's preferences, keyed by folder
  path). The shell adds only what AppKit lacks: the Open panel chooses
  folders, and shows in place of an untitled document; and one wiring line
  in FolderView hosts the workflow's root view. The document never saves;
  workflows write keeps.json themselves.

**Dependency rule: Kit never imports from Workflows.** The kit must stay
free of workflow vocabulary (marks, filters, sort destinations).

To start a new workflow experiment: create `Keeps/Workflows/<name>/` with
its own state and root view, give its persisted state a distinct workflow
name (the keeps.json envelope ignores state written by other workflows),
and swap the one wiring line in FolderView.

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
