# Plan: Group Focus Filter

## Goal

Add a `.group(UUID)` case to `FilterMode` so the user can focus the grid on a single
group's photos (intersected with the current pass's visible photos). Activated via a
Photo menu command; exited by clicking any filter button in the toolbar.

## Steps

### Step 1: Model + tests

**Files:** `Models/FolderLibrary.swift`, `KeepsTests/FilterTests.swift`

- Add `.group(UUID)` to `FilterMode`. Swift auto-synthesizes `Equatable` and `Hashable`
  since `UUID` is both.
- Update `updateFilteredItems()` to handle `.group(id)`: show only items in
  `currentPassPhotoIDs` that are also in the given group. Fall back to
  `currentPassPhotoIDs` if the group no longer exists.
- Add `focusSelectedItemGroup()`: sets `filterMode = .group(group.id)`, calls
  `updateFilteredItems()`, keeps `selectedItemID` in place (doesn't reset to index 0).
  Does nothing if the selected item isn't in a group.
- Add `var isGroupFocused: Bool` computed property — true when `filterMode` is `.group`.
  Used to control "Focus Group" command state and toolbar indicator.
- Update `ungroupSelectedItem()`: if `filterMode == .group(deletedGroup.id)`, reset
  `filterMode` to `.all` before removing the group.
- Update `startNextPass()` and `selectPass()`: reset `filterMode` to `.all` (group focus
  doesn't make sense after switching passes).
- Write tests for:
  - Group focus shows only current-pass members of the focused group
  - Photos outside the group are hidden
  - Focus on an unknown UUID falls back to `currentPassPhotoIDs`
  - `ungroupSelectedItem` resets filter when the focused group is deleted
  - `startNextPass` resets group focus to `.all`
- Review and commit.

### Step 2: UI

**Files:** `Views/PhotoCommands.swift`, `Keeps/ContentView.swift`

- Add "Focus Group" to `PhotoCommands`, after the "Reject Rest of Group" button:
  - Disabled when `library?.selectedGroupID == nil`
  - Calls `library?.focusSelectedItemGroup()`
- In `ContentView`, update the toolbar filter picker so that when `filterMode` is
  `.group(...)`, the picker selection renders cleanly. The simplest approach: wrap the
  picker's `get` to map `.group(...)` → `.all` for display only, while keeping
  `applyFilter` wired to `set` as normal. This makes "All" appear selected while in group
  focus mode, which is slightly misleading but avoids a blank-selection state.
  Alternatively, show a small "Group Focus" label with an × button when in group focus
  mode. Decide during implementation which looks better.
- Review and commit.
