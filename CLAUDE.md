# CLAUDE.md

## Architecture

The app is split into a stable rendering kit and the culling workflow
built on it:

- `Keeps/Kit/` — stable ground: the image engine (ImagePipeline,
  ImageCache, ImageReader), folder scanning and session (FolderScanner,
  FolderSession), keeps.json and the generic persistence harness
  (WorkflowPersistence), and dumb viewing surfaces
  (PhotoGridSurface, PhotoDetailSurface, ThumbnailImage). Surfaces
  interpret spatial keys into NavigationProposals and take cells/overlays
  via ViewBuilder closures; they know nothing about groups, keepers, or any
  other workflow concept.
- `Keeps/Workflows/GroupCull/` — everything the workflow owns: its state,
  screens, cell chrome, keymap, toolbar, dialogs, and persistence schema.
  Photos are grouped by clicking between them, and finished groups
  collapse.
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
  folders, and shows in place of an untitled document; and FolderView
  hosts the workflow's root view. The document never saves; the workflow
  writes keeps.json itself.

**Dependency rule: Kit never imports from Workflows.** The kit must stay
free of workflow vocabulary (groups, keepers, done status).

keeps.json stores the workflow name ("group-cull") alongside the state.
Keep it: folders already saved in that format must still restore.

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
