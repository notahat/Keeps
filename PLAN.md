# Plan: Measuring, then sharpening the tiles

## Goal

Image loading feels fast, even flicking through full-size views, and
memory isn't a concern: the app may be memory hungry as long as it stays
fast. So add complexity (cache budgets, different preloading) only when a
measurement shows a problem it would fix. The tiles are now sharper, and
the findings that shaped the image sizes are in `Benchmarks/README.md`.

## What to measure

- **Time to sharp.** From asking for an image (a step at full size, a
  group opening) to the good image being on screen, rather than the
  thumbnail standing in. The main measure.
- **Sharp straight away.** The share of steps whose image was already
  cached or preloaded.
- **Hitches.** Frames where the main thread stalls.
- **Memory over time.** Mainly to catch macOS squeezing the app, when
  NSCache would drop everything at once.

The signposts (`ImageSignposts`) show these in Instruments, and the debug
overlay (Debug ▸ Show Image Statistics, ⌥⌘I) shows them in the app.

## Scenarios

Run the same way each time, so results compare across changes:

1. **Open a large folder cold.** How long until every thumbnail is
   cached, and the memory afterwards.
2. **Open a big group.** How long until every tile is sharp.
3. **Hold the right arrow at full size.** Key repeat steps at a steady
   rate. The share of steps sharp straight away, and time to sharp.
4. **Step at a normal pace,** about one photo a second.

The sandbox stops Claude launching the app or Instruments, so the user
runs the scenarios and shares the overlay's numbers or a saved trace.

## What good looks like

To be agreed with the baseline in hand, but roughly: normal stepping is
always sharp straight away, tiles are sharp within a quarter of a
second, and nothing hitches. A change is worth keeping when it moves one
of these.

To check in the app:

- **Jaggedness.** A big group on the laptop has tiles of about 700 px
  showing a 1932-pixel image, shrunk nearly three times on screen. If
  that looks jagged, a further size around 1024 px would fix it, at no
  extra cost for a JPEG.
- **Hitches** while a big group's medium images arrive, from preparing
  them for display.

## Steps

1. **Baseline.** The user runs the four scenarios. Record the results
   here and agree what good looks like.
2. **Review.** Look over the numbers for anything else worth doing, and
   plan it separately if so.

# Plan: Bringing the code in line with the coding guidelines

## Goal

A review of the code against the rewritten global CLAUDE.md found one
bug, some duplication, logic sitting in views without tests, silent
fallbacks, names that drift from the glossary, and function comments in
several styles. This plan fixes them, bug first, then structure, then
the smaller and more mechanical changes.

## Decisions

- **Function names.** Functions with side effects or I/O start with a
  verb (`readImage(from:)`, `makeAppMenu()`). Pure lookups and SwiftUI
  view builders may keep the noun names Swift's API guidelines give them
  (`photoIndex(forGap:)`, `header`). Recorded in the project CLAUDE.md,
  which wins over the global one.
- **`$0`.** Fine in one-line closures whose meaning is plain. Name the
  parameters where the order or meaning isn't obvious, such as
  `map { ($1.stem, $0) }`, or in nested closures. Also recorded in the
  project CLAUDE.md.
- **Function comments** are imperative sentences ("Return the cell a
  movement key goes to…"), not noun phrases or the third person.
- **keeps.json doesn't change.** Renames that touch `SavedGrouping` or
  `KeepsFile` keep their keys on disk through `CodingKeys`, and the
  existing format fixtures stay as they are.
- **The measuring plan above stays** until its Baseline and Review steps
  are done.

## Steps

Each step builds and passes the tests, then stops for review before a
commit.

1. ✅ **Clear out finished plans.** Move the decode benchmark results, the
   first traces, the decoder's cheap sizes, and the tile sizes from the
   measuring plan into `Benchmarks/README.md`, worded as they stand
   rather than as plan steps, and drop its line pointing at PLAN.md.
   Delete the nine finished plans and the measuring plan's done design
   sections, keeping its goal, what to measure, scenarios, what good
   looks like, and its open steps. Git keeps the history.
2. ✅ **The done screen keeps its selection (bug).** `DoneScreen` finds the
   last opened group through `selectedPhotoIndex`, but closing a done
   group moves the selection to the next group that isn't done, so the
   selection is almost always lost. Test first: Grouping remembers the
   last opened group after it closes. Then `Grouping.lastOpenedGroup`,
   kept in memory only, and `DoneScreen` uses it.
3. ✅ **Image sizes out of `FramedPhoto`.** The thumbnail and medium image
   sizes and the choice between them move from the view to
   `ImageSize.swift`. The benchmark uses the real values instead of
   copies of 520 and 1932, and `FramedPhotoTests` becomes
   `ImageSizeTests` without `@MainActor`. (The aspect ratio helpers stay
   on `FramedPhoto` until step 6: `commonAspectRatio` reads the image
   cache, which the benchmark doesn't compile.)
4. ✅ **Full image priorities.** Tiles request `.full` images at the same
   top priority as the photo shown full size. Decide with the user
   whether a tile's full image should rank lower, change the code if so,
   and correct the comments in `ImagePipeline` and `ImageSize`. (Left as
   it is: only small groups have tiles that large, so only a few read at
   once. Revisit if the baseline shows a problem.)
5. ✅ **One click gesture.** The click and double-click handling copied
   into the four screens becomes one modifier in Keys, beside
   `handlesKeys`, with its explanation written once.
6. ✅ **One scrolling tile grid.** The tile grid that `PickScreen` and
   `KeepersScreen` both build (state, spacing, scroll tracking,
   `reveal`, stepping at full size, the full-size overlay) becomes one
   view in Images, `ScrollingTiles`. Stepping at full size, clamped to
   the ends, becomes a pure function on `TileLayout`, tested. The shared
   grid spacing and pile border width get one definition each.
   (`FramedPhoto.commonAspectRatio` stays put: `ScrollingTiles` is generic
   over its tile view, so a static on it would be awkward to call. The
   keepers screen's full-size view is now inset by the grid spacing, as
   the pick screen's is, rather than nearly twice that.)
7. ✅ **Scrolling decisions out of `GridScrolling`.** Whether a change holds
   position, follows the selection, or does nothing becomes a pure,
   tested function returning an enum. `PhotoGridMetrics.
   scrollOffsetHoldingItem`'s seven parameters become a before and an
   after value.
8. ~~**Step timing out of `FullSizeImage`.** The rules for a step that's
   moved on from and a step that's sharp at once become a pure value,
   tested like `ImageLoadStats`, with the view making the signpost and
   pipeline calls.~~ Skipped: the pending step carries its signpost, so a
   pure timer would have to be generic over it, with the view still
   deciding each case. That's harder to follow than the 25 lines it
   would replace.
9. ✅ **The group number from Grouping.** `PickScreen.header` stops working
   out the group number itself, and with it the `?? 0` that would show
   "Group 1" for a missing group. Grouping provides it, tested.
10. ✅ **Fail loudly.**
    - `FolderScanner.creationDate` throws rather than giving 1970.
    - `ImagePipeline` logs a failed read with the file's path, and the
      preview loader stops with `fatalError`.
    - Guards in Grouping against calls that can't happen (bad indexes,
      marking done with no group open, opening something that isn't a
      group) become preconditions, and the tests of ignoring them go.
      Guards for real user actions stay.
    - A scroll anchor that isn't in the folder is a precondition failure.
    - Clamps that can't take effect go: `KeepersScreen`'s index clamp and
      tile count guard, `PhotoGridMetrics`' column count checks, and the
      bounds checks in `TileLayout`.
    - The benchmark checks for a folder instead of relying on `try?`.
    - `borderColor` goes from `FramedPhoto` and `BlankPrint`, since it's
      always white.
11. ✅ **One name per concept.**
    - `items` becomes `photos` wherever it means the folder's photos.
    - Pick's "focused" tile becomes "selected", like the other screens.
    - `DoneScreen`'s cells become piles.
    - Sort's "item" for a grid position becomes cell or slot, and
      `PhotoGridMetrics`' slot parameters say slot.
    - `FullSizeImage` becomes `FullSizePhoto`, and `TileLayout`'s private
      `Grid` becomes `TileGrid`.
    - Paper becomes blank print.
    - "Stats" becomes "Statistics", keeping the `showsImageStats`
      settings key.
    - Add "to go" and "set aside" to the glossary.
    (`PhotoItem` keeps its name, but every variable and parameter holding
    one says photo. The sort grid identifies cells by their photos' ids,
    so its scrolling speaks of photo ids, and `GridHitTarget.item` became
    `.cell`. The glossary also gained photo, slot, blank print, and
    selected.)
12. ✅ **Names that say what they do.**
    - Record the two naming decisions above in the project CLAUDE.md.
    - Functions with side effects get verbs: `makeAppMenu()` and the
      other menus, `readImage(from:size:)`,
      `readLongestSideLength(of:)`, `readMemoryFootprint()`,
      `FolderWindowController.show(_:)`, `snapshotState()` and
      `applyRestored(state:)`.
    - Booleans start with is, has, or should: `needsScrolling`,
      `loadsInBackground`, and `isAutoSaving` (which becomes
      `isStopped`).
    - `workflow` becomes `formatName`, keeping the `"workflow"` key on
      disk.
    - Name the `$0` parameters picked out in the review, and the
      pattern-named test helpers `StubModel` and `ErrorBox`.
    (`snapshotState()` and `applyRestored(state:)` became
    `makeSavedGrouping()` and `restore(from:)`, `needsScrolling` became
    `isScrollable`, `loadsInBackground` became `shouldLoadInBackground`,
    and `show(_:)` became `updateTitle(for:)`. The test helpers are
    `ObservableSelection` and `ReportedError`.)
13. ✅ **Comments.**
    - Rewrite function comments as imperative sentences.
    - Give sizes their units.
    - Add the missing doc comments, and a header for `KeyHandling.swift`.
    - Fix the stale ones: `PhotoItem`, `TestHelpers`, and
      `FullSizeImage`'s "sort screen's thumbnail".
    - Remove words that point to the future, such as "yet".
    - Drop `PhotoGridMetrics`' repeated "Pure.".
    - Name the preload window's 2 back and 4 ahead as constants.
14. ✅ **Tests.**
    - Give the scanner and session tests sentence names.
    - Split, or use `@Test(arguments:)` for, tests that check several
      things.
    - Move misplaced tests to the files for what they test.
    - Use `#require` where a check guards later steps.
    - Delete the reader tests' temporary files.
    - Derive the hit target threshold from `edgeFraction` and test the
      right edge.
    (The source URL test moved to a new `PhotoItemTests`, with a JPEG
    case added, and the grid movement tests joined `PhotoGridMetricsTests`.
    `makePhotos`' URLs now match their stems. Tests whose checks together
    describe one result, such as a round trip or a tile's width and
    height, stay whole.)
15. ✅ **Small things.**
    - `isPlainLetter` moves out of `MoveDirection.swift`.
    - `PileLabel` gets its own file.
    - `placedInPile` becomes private.
    - `Array.sum(of:)` is inlined.
    - `FolderSidebar`'s padding parameter goes, and its corner radius
      becomes one constant.
    - `PhotoDragSource`'s empty guard goes.
    - The folder READMEs catch up with their folders and state the
      screens' layering rule the same way.
    (`isPlainLetter` is in `Keys/PlainLetter.swift`, with its tests in
    `PlainLetterTests`. Every README now ends with what its folder uses,
    in the same words.)
