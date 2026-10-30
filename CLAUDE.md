# CLAUDE.md

## Architecture

The code under `Keeps/` is organised by what each part of the app does.
Each folder's `README.md` describes its responsibilities; update it when
they change. The READMEs are excluded from the app target in the project
file (otherwise they'd collide as bundle resources), so a README in a new
folder needs adding to that exception list.

- `App/` — the shell, built on AppKit's document architecture, plus
  `Keeps-Info.plist` at the project root. Each open folder is a
  `FolderDocument` (the plist declares folders as a document type with
  that class), so AppKit provides Open, Open Recent, opening folders
  dropped on the Dock icon, bringing an open folder's window forward,
  reopening folders at launch (`NSQuitAlwaysKeepsWindows` is registered so
  this happens whatever the system setting), sandbox access to them,
  including after a relaunch, and saving each window's frame. The shell
  adds only what AppKit lacks: the Open panel chooses folders, and shows in
  place of an untitled document. `FolderView` owns the folder's `Grouping`
  and its `KeepsFile`, and shows the sort screen. The document never saves;
  `KeepsFile` writes keeps.json as the grouping changes.
- `Folder/` — scanning a folder into photos (`PhotoItem`, `FolderScanner`,
  `FolderSession`).
- `Images/` — loading, caching, and showing images (`ImagePipeline`,
  `ThumbnailImage`, load progress).
- `Grouping/` — the model: `Grouping` holds the boundaries, collapse point,
  selection, and scroll position, and `GroupLayout` derives the cells.
- `Saving/` — keeps.json: `KeepsFile` reads and writes it, and
  `SavedGrouping` is its format.
- `Sort/` — the sort screen. `SortScreen` draws cells and handles input;
  `GridScrolling` does the scrolling; the geometry is in pure, tested
  helpers (`PhotoGridMetrics`, `GridHitTarget`).
- `Pick/` — the pick screen, being built (see PLAN.md).

**Layering.** The folders use each other only like this, with no cycles:

- App uses everything.
- Sort and Pick use Grouping, Images, and Folder, and never each other.
- Grouping uses Saving and Folder, converting itself to and from
  `SavedGrouping`.
- Images uses Folder.
- Saving uses nothing.

Grouping, Saving, and Folder have no views, which keeps them testable.

**keeps.json files already on disk must keep loading.** Real folders have
been grouped, and losing that work is not acceptable. Any change to the
saved format must still restore every earlier format, by converting it on
load, with a test that restores a hand-written file in the old format (see
`originalFormatRestores` in SavedGroupingTests). Never edit an existing
format fixture to make a test pass. The file's `"workflow"` field names
its format (`SavedGrouping.originalFormatName`, `"group-cull"`), so a new
format can be written under a new name and the old one recognised by its
name.

## Glossary

- **Group**: a run of photos between two boundaries. No type is called
  plain `Group`, which SwiftUI already has; use `PhotoGroup` if one is
  needed.
- **Boundary**: the split between two groups, placed by clicking between
  photos.
- **Working point**: where grouping has reached, the first photo after the
  last boundary. It holds still on screen as groups collapse.
- **Collapsed**: a closed group drawn as a pile, after C. It can't be
  changed.
- **Sort screen**: the grid where the folder is split into groups.
- **Pick screen**: one group at a time, where its **keepers** are picked
  and the group is marked **done**.

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
