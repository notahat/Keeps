# Images

Loading, caching, and showing photos. `ImageReader` decodes files into
images; `ImagePipeline` schedules those reads on a bounded queue, with
on-screen requests ahead of background prefetching, caches the results in
`ImageCache`, and posts a notification as each image arrives so views can
update. `ThumbnailImage` is the view that shows a thumbnail, and
`LoadProgressView` the toolbar ring showing how far the current burst of
loading has got. `PrintPile` draws photos as a messy pile of prints, only
the top few showing their photos and the rest `BlankPrint`s, with
`PileLabel` for its caption, and `PileJitter` works out how each print sits
in a pile, tilted and nudged by its stem, so both screens' piles look
alike.

Uses only Folder, for `PhotoItem`. Knows nothing about groups: selection
highlights and boundary bars are drawn by the screens on top of
`ThumbnailImage`.
