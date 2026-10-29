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
- **Collapsing is manual.** Pressing C collapses every group closed so far;
  groups closed afterwards stay open until the next press. The workflow
  stores only the photo index collapsing reaches. There is no un-collapse.
  (Automatic collapsing of all but the two most recent groups was tried
  first and dropped.)
- **Layout stability.** Nothing you're looking at moves when groups
  collapse. The grid leaves blank slots before the first cell for the
  photos hidden inside collapsed groups (modulo the column count), so open
  photos keep their original columns. The working point (the first photo
  after the last boundary) is held at the same height on screen. Before
  there is one, a click holds the clicked photo and a key press holds the
  photo in the middle of the view. A click never scrolls the selection into
  view. Changes are not animated.
- **Collapsed group.** Shown as one cell: a messy pile of up to eight of
  the group's photos as white-bordered prints, with a count badge.
  Collapsed groups are finished: the gaps on either side show no boundary
  bar and can't be toggled.
- **Selection.** The folder opens with nothing selected, and Escape clears
  the selection. Clicking a collapsed group selects it; it does not expand.
  (Temporary expansion for editing was tried and set aside for now.)
- **Full-size view.** Double-click opens the existing detail surface,
  read-only; Esc returns. No boundary editing from the full-size view.
- **Persistence.** `keeps.json` state under the workflow name `group-cull`,
  so a folder reopens exactly where it was left: each boundary (as "before
  this photo's stem" or "end"), the collapse point, the selected photo, and
  the scroll position. Stems no longer in the folder are dropped when the
  state is loaded.
- **Input.** Boundaries are placed with the mouse. The keyboard has C to
  collapse, Escape to clear the selection, and arrow-key navigation as the
  surface provides it.

### Kit boundary

Kit learns a generic, spatial notion of a *gap*: "the gap before item i".
`PhotoGridSurface` resolves a click to either an item or a gap, reports
which gap the pointer is hovering, and maps both sides of a row wrap to the
same gap. It knows nothing about groups or boundaries. The workflow turns
gap clicks into boundary toggles, keeps track of the hovered gap Kit
reports, and draws the bars in its own cells. These callbacks are optional,
so SimpleCull's behaviour is unchanged.

### Out of scope

Picking keepers, progress indicators, dimming or truncating unreached
photos, putting each group on its own row, keyboard boundary toggling, and
boundary suggestions from time gaps. Photos are ordered by file creation
date and EXIF capture times are not read, so time-gap suggestions would
need that first.

## Steps

Each step includes tests where there is testable behaviour, then review and
commit.

1. ✅ **Gap hit-testing in Kit.** A pure function mapping a click position
   within a cell (plus the cell's width and index) to an item or a gap
   index, covering the row-wrap equivalence and the ignored leading gap.
   Tested with Swift Testing. Add optional `onGapTap` and hover-gap
   reporting to `PhotoGridSurface`, and suppress item selection for edge
   clicks.
2. ✅ **Grouping model.** `GroupCull` state holding the boundary set and the
   collapse point, and a pure derivation from photos plus boundaries to
   groups, collapsed or open status, and the list of cells to display.
   Toggling, finishing, and collapsing are covered by tests.
3. ✅ **Grouping UI.** The root view wired into `ContentView`, cell chrome
   drawing the boundary bars and hover preview, and gap clicks toggling
   boundaries. First point where the app can be tried.
4. ✅ **Collapsing.** Pressing C collapses closed groups into messy-pile
   cells with a count badge, holding the working point still.
5. ✅ **Persistence.** The `group-cull` state schema with snapshot and
   restore of boundaries, collapse point, selection, and scroll position,
   tested like `SimpleCullStateTests`.
6. **Read-only detail view.** Double-click to open the photo at full size,
   Esc to return.
