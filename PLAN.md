# Plan: Photo Grouping Feature

## Context

The user wants to mark related photos (bursts, same-scene shots) as a visual group, then quickly reject all non-picks in the group. Groups are persistent at the folder level (survive across passes and restarts) and are shown as auto-colored bottom bars on thumbnails.

**Interaction flow:**
1. Click a photo, shift+click another → selects the range (highlighted in grid)
2. Press G → creates a group from the range; colored bar appears on all photos in it
3. Navigate, pick favorites with F as today
4. Photo menu → "Reject Rest of Group" → rejects all group members in the current pass that aren't already picks

## Implementation Steps

1. **Range selection in the grid** — shift+click/arrow to select a range; highlight in `ThumbnailView`
2. **Bulk mark on selection** — F/S/D marks all items in range; single-select behavior unchanged
3. **Grouping UI** — in-memory group model, color bars on thumbnails, G to create a group from selection
4. **Group persistence** — save/restore groups in `keeps.json`, backward-compat with old files
5. **Reject-rest** — "Reject Rest of Group" command in Photo menu

---

## Data Model

### `LibraryState.swift`

Add `PhotoGroup` and a `groups` field:

```swift
struct PhotoGroup: Codable, Identifiable {
    var id: UUID
    var colorIndex: Int    // index into FolderLibrary.groupColors
    var stems: [String]    // stem-based so state survives folder moves
}

struct LibraryState: Codable {
    struct Pass: Codable { ... }   // unchanged
    var passes: [Pass]
    var groups: [PhotoGroup] = []  // default = [] for backward compat
}
```

### `FolderLibrary.swift` (in-memory representation)

Add a parallel `PhotoGroup` (UUID-based) and new state:

```swift
struct PhotoGroup {
    var id: UUID
    var colorIndex: Int
    var itemIDs: Set<UUID>   // translated from stems on restore
}

static let groupColors: [Color] = [
    .orange, .purple, .cyan, .yellow, .pink, .mint
]

private(set) var groups: [PhotoGroup] = []
private(set) var rangeAnchorID: UUID? = nil  // anchor for shift-click range
```

New computed properties and methods:

```swift
// Range of filteredItems indices currently selected (anchor → selection)
var selectionRange: ClosedRange<Int>?

// Unified selection: sets selectedItemID and clears anchor (normal click/nav)
func selectItem(at index: Int)

// Extends selection from anchor to index (shift+click/shift+arrow)
func extendSelection(to index: Int)

// Color for a photo's group, nil if ungrouped
func groupColor(for id: UUID) -> Color?

// Creates a group from the current selectionRange
func createGroupFromSelection()

// Rejects all group members of the selected photo that are in the current
// pass and not already marked as picks
func rejectRestOfGroup()

// Computed: the items currently in selectionRange
var selectedRangeItems: [PhotoItem]

// Used by LibraryPersistence
func applyRestoredGroups(_ groups: [PhotoGroup])
```

`close()` must reset `groups = []` and `rangeAnchorID = nil`.

Color assignment: `nextGroupColorIndex` scans existing groups and picks the least-used index (or cycles).

---

## Persistence (`LibraryPersistence.swift`)

- `startObserving(_:)` must also track `library.groups` (add to the observed access)
- `save(_:)` translates `PhotoGroup.itemIDs` → stems for `LibraryState.PhotoGroup`
- `restore(into:)` translates `LibraryState.PhotoGroup.stems` → UUIDs using `idByStem`, calls `applyRestoredGroups`
- Old `keeps.json` with no `groups` key decodes fine via the default value

---

## Grid View (`Views/GridView.swift`)

**Range selection:**
- Tap gesture handler: check `NSApp.currentEvent?.modifierFlags.contains(.shift)`
  - Normal tap: call `library.selectItem(at: index)` (replaces `library.selectedIndex = index`)
  - Shift-tap: call `library.extendSelection(to: index)`
- Key handler: check `event.modifierFlags.contains(.shift)` before calling navigation
  - With shift: call `library.extendSelection(to: newIndex)`
  - Without shift: call `library.selectItem(at: newIndex)`

**Passing data to ThumbnailView:**
```swift
ThumbnailView(
    item: item,
    isSelected: item.id == library.selectedItemID,
    isInSelectionRange: library.selectionRange?.contains(index) ?? false,
    mark: library.mark(for: item.id),
    groupColor: library.groupColor(for: item.id)
)
```

---

## Thumbnail View (`Views/ThumbnailView.swift`)

Add two new parameters:
```swift
var isInSelectionRange: Bool = false
var groupColor: Color? = nil
```

**Range highlight:** when `isInSelectionRange && !isSelected`, show a subtle tinted overlay (e.g. `.accentColor.opacity(0.25)`)

**Group color bar:** at the bottom of the cell, a 4pt rectangle in the group color:
```swift
.overlay(alignment: .bottom) {
    if let color = groupColor {
        Rectangle().fill(color).frame(height: 4)
    }
}
```

---

## Single Image View (`Views/SingleImageView.swift`)

Add a small group color bar at the bottom edge (similar placement to the `X / Y` counter but left-aligned or separate), so groups are visible in single-image mode too.

---

## Menu Commands (`Views/PhotoCommands.swift`)

Add two commands after a separator:

```swift
Divider()
Button("Group Selection") {
    library?.createGroupFromSelection()
}
.keyboardShortcut("g", modifiers: [])
.disabled((library?.selectedRangeItems.count ?? 0) < 2)

Button("Reject Rest of Group") {
    library?.rejectRestOfGroup()
}
.disabled(library?.selectedItemIsGrouped != true)
```

---

## Critical Files

| File | Change |
|------|--------|
| `Models/LibraryState.swift` | Add `PhotoGroup`, `groups` field (Step 4) |
| `Models/FolderLibrary.swift` | Add group state, range selection, group methods |
| `Models/LibraryPersistence.swift` | Save/restore groups; observe group changes (Step 4) |
| `Views/GridView.swift` | Shift+click/arrow range selection; pass groupColor + isInSelectionRange |
| `Views/ThumbnailView.swift` | Range highlight overlay; group color bar |
| `Views/SingleImageView.swift` | Group color indicator (Step 3) |
| `Views/PhotoCommands.swift` | Group Selection (Step 3) + Reject Rest of Group (Step 5) |

---

## Tests

- Extending selection with `extendSelection(to:)` correctly computes `selectionRange`
- Bulk mark: F/S/D on a range marks all items; single-select still marks-and-advances
- `createGroupFromSelection` creates a group with correct item IDs and assigns a color
- `groupColor(for:)` returns color for grouped photos, nil for ungrouped
- `rejectRestOfGroup` rejects non-picks in the group, leaves picks alone, ignores photos not in current pass
- Groups survive round-trip through `save` → `restore`
- Old `keeps.json` without `groups` key migrates cleanly (no crash, empty groups)

---

## Verification

1. Open a folder, select a range with shift+click → range highlights in grid
2. Shift+arrow also extends selection; normal arrow clears it
3. Press F/S/D on a range → all items marked; single-select still advances
4. Press G → colored bar appears on grouped thumbnails
5. Pick a couple with F, then "Reject Rest of Group" → others become rejects
6. Close and reopen the folder → groups and their colors persist
7. Open an old folder with no `groups` in keeps.json → loads without error
