# Images

Loading, caching, and showing photos.

`ImageReader` decodes files into images. `ImagePipeline` schedules those
reads on a bounded queue, with on-screen requests ahead of background
prefetching, and caches the results in `ImageCache`. Views hear as each
image arrives through `onImageLoaded(for:)`. `ThumbnailImage` is the view
that shows a thumbnail, and `LoadProgressView` is the toolbar ring showing
how far the current burst of loading has got.

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

Images uses only Folder, for `PhotoItem`. It knows nothing about groups:
the screens track which item is selected and draw the sort screen's
boundary bars themselves.
