# Images

Loading, caching, and showing photos. `ImageReader` decodes files into
images; `ImagePipeline` schedules those reads on a bounded queue, with
on-screen requests ahead of background prefetching, caches the results in
`ImageCache`, and tells views as each image arrives, through
`onImageLoaded(for:)`. `ThumbnailImage` is the view that shows a thumbnail, and
`LoadProgressView` the toolbar ring showing how far the current burst of
loading has got. `PrintPile` draws photos as a messy pile of prints, only
the top few showing their photos and the rest `BlankPrint`s, with
`PileLabel` for its caption, and `PileJitter` works out how each print sits
in a pile, tilted and nudged by its stem, so both screens' piles look
alike. `PreviewPhotos` gives SwiftUI previews photos from the JPEGs in
Preview Content, already cached; release builds leave those files out, so
nothing else may use it.

`SelectionHighlight` is the outline every screen draws round a selected
photo or pile, and `KeeperBadge` marks a keeper; its colour stands for the
keepers wherever they're shown.

Uses only Folder, for `PhotoItem`. Knows nothing about groups: which item
is selected, and the sort screen's boundary bars, are the screens' own.
