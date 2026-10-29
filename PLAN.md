# Plan: GroupCull — grouping photos by clicking between them

## Goal

Experiment with a culling UI that limits what you see at once and gives a
sense of progress. The hypothesis is two fast passes: first group photos,
then pick a few keepers from each group. This plan covers **grouping only**.
Selection gets its own design session once grouping has been tried.

## Design

- **New workflow.** `Keeps/Workflows/GroupCull/`, swapped in via the wiring
  line in `ContentView`. `SimpleCull` stays untouched for comparison.
- **Linear sweep.** You work front to back. The folder always starts a group
  before the first photo. Photos after the last boundary are ungrouped
  (unreached) and are shown normally.
- **Boundaries.** Clicking between two photos toggles a boundary there. The
  click targets are edge zones (roughly the outer 20% of each cell's width),
  not the thin gap itself. An edge click never selects the photo. Hovering
  an edge zone previews the boundary. A boundary is drawn as a vertical bar
  in the gap, or in the margin at a row's start or end. The right edge of
  the last cell in a row and the left edge of the first cell in the next row
  are the same gap. The gap before the first photo is ignored. Placing a
  boundary never reflows the layout.
- **Finishing.** A boundary after the last photo closes the final group.
- **Collapsing is derived from the boundaries.** All groups except the two
  most recently closed ones are collapsed. Removing the last boundary
  therefore re-expands a group. No collapse state is stored.
- **Collapsed group.** Shown as one cell: the group's first photo with a
  count badge and a stacked-cards look.
- **Temporary expansion.** Clicking a collapsed group expands it in place so
  its boundaries can be edited. Only one group is expanded at a time, and it
  re-collapses on clicking elsewhere or placing a new boundary.
- **Full-size view.** Double-click opens the existing detail surface,
  read-only; Esc returns. No boundary editing from the full-size view.
- **Persistence.** `keeps.json` state under the workflow name `group-cull`,
  storing the stem of the first photo of each group. Stems no longer in the
  folder are dropped when the state is loaded.
- **Input.** Mouse only for now. Arrow-key navigation keeps working as the
  surface provides it.

### Kit boundary

Kit learns a generic, spatial notion of a *gap*: "the gap before item i".
`PhotoGridSurface` resolves a click to either an item or a gap, reports
which gap the pointer is hovering, and maps both sides of a row wrap to the
same gap. It knows nothing about groups or boundaries. The workflow turns
gap clicks into boundary toggles and draws the bars itself, using the hover
information Kit passes to each cell. These callbacks are optional, so
SimpleCull's behaviour is unchanged.

### Out of scope

Picking keepers, progress indicators, dimming or truncating unreached
photos, putting each group on its own row, keyboard boundary toggling, and
boundary suggestions from time gaps. Photos are ordered by file creation
date and EXIF capture times are not read, so time-gap suggestions would
need that first.

## Steps

Each step includes tests where there is testable behaviour, then review and
commit.

1. **Gap hit-testing in Kit.** A pure function mapping a click position
   within a cell (plus cell index and column count) to an item or a gap
   index, covering the row-wrap equivalence and the ignored leading gap.
   Tested with Swift Testing. Add optional `onGapTap` and hover-gap
   reporting to `PhotoGridSurface`, and suppress item selection for edge
   clicks.
2. **Grouping model.** `GroupCull` state holding the boundary set, and a
   pure derivation from photos plus boundaries to groups, collapsed or open
   status, the temporarily expanded group, and the list of cells to display.
   Toggling, finishing, and re-expansion on removal are all covered by tests.
3. **Grouping UI.** The root view wired into `ContentView`, cell chrome
   drawing the boundary bars and hover preview, and gap clicks toggling
   boundaries. First point where the app can be tried.
4. **Collapsing.** Collapsed-group cells with the badge and stack look, and
   click-to-expand-temporarily.
5. **Persistence.** The `group-cull` state schema with snapshot and restore,
   tested like `SimpleCullStateTests`.
6. **Read-only detail view.** Double-click to open the photo at full size,
   Esc to return.
