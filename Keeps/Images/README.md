# Images

Loading, caching, and showing photos. `ImageReader` decodes files into
images; `ImagePipeline` schedules those reads on a bounded queue, with
on-screen requests ahead of background prefetching, caches the results in
`ImageCache`, and posts a notification as each image arrives so views can
update. `ThumbnailImage` is the view that shows a thumbnail, and
`LoadProgressView` the toolbar ring showing how far the current burst of
loading has got. `PileJitter` works out how a print sits in a messy pile,
tilted and nudged by its stem, so both screens' piles look alike.

Uses only Folder, for `PhotoItem`. Knows nothing about groups: selection
highlights and boundary bars are drawn by the screens on top of
`ThumbnailImage`.
