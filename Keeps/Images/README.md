# Images

Loading, caching, and showing photos.

`ImageReader` decodes files into images, scaled to the size asked for.
`ImageSize` names the three sizes of image, and chooses which of them a
frame shows:

- a **thumbnail**, 520 pixels long, for the sort screen's cells, piles,
  and drag images, and to stand in while a larger image loads;
- a **medium image**, 1932 pixels long, for tiles too large for a
  thumbnail;
- a **full image**, no bigger than the JPEG preview in the user's RAW
  files, since a full-resolution image costs a long pause on the main
  thread when it first shows.

`ImageReader` hands each file to the reader for its format.
`RAWImageReader` reads a RAW file's embedded preview, as it is for a full
image. `JPEGImageReader` reads a JPEG file's full image at half its size
or less, which its decoder reads quickly, and a scaled image of an eighth
of its size or less at a quarter, then shrinks it, since its decoder
reads that size twice as quickly. `ImagePipeline` schedules those
reads on a bounded queue, with on-screen requests ahead of background
prefetching, and caches the results in `ImageCache`. A view showing an
image keeps its `WatchedImage`, which redraws only that view when the
image arrives.

`FramedPhoto` shows a photo in a fixed frame, for cells, tiles, and
piles. It shows the image `ImageSize` chooses for the frame's size in
pixels, with the thumbnail standing in until a larger image loads. `FullSizeImage` shows a photo
full size, with its thumbnail standing in until it loads and its
neighbours preloaded. `LoadProgressView` is the toolbar ring showing how
far the current burst of loading has got.

`TileLayout` lays photos out as an even grid of tiles, for the pick and
keepers screens. It's the pure, tested part: the column count, tile size,
and positions, where the movement keys go, how far to scroll to reveal a
tile, and the photos' common aspect ratio.

`ImageStatsOverlay` is a debug panel of figures for tuning loading: the
app's memory, what `ImageCache` holds at each size, reads in flight, the
hit rate, and how quickly recent full-size steps turned sharp, which
`ImageLoadStats` keeps. Debug builds turn it on from the Debug menu.
`ImageSignposts` marks the same loading for Instruments: each read, cache
hits, misses, and evictions, and each full-size step until it turns
sharp.

`PrintPile` draws photos as a messy pile of prints, with only the top few
showing their photos and the rest drawn as `BlankPrint`s. `PileLabel` is
its caption. `PileJitter` works out how each print sits in a pile, tilted
and nudged by its stem, so a photo sits the same way in every pile it
appears in.

`PreviewPhotos` gives SwiftUI previews photos from the JPEGs in Preview
Content, already cached. Release builds leave those files out, so nothing
outside a preview may use it.

`SelectionHighlight` is the outline every screen draws round a selected
photo or pile, and `KeeperBadge` marks a keeper; its colour stands for the
keepers wherever they're shown.

Images uses Folder, for `PhotoItem`, and Keys, for `MoveDirection`. It
knows nothing about groups: the screens track which item is selected and
draw the sort screen's boundary bars themselves.
