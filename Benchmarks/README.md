# Benchmarks

`run-decode-benchmark` times the app's image reads (`ImageReader`) over
sample photos. For each photo it shows the size of image each read gives
back, and how long the read and a first draw take. The comment at the top
of `DecodeBenchmark.swift` explains the two times.

Copy some photos into `Samples/` at the project root (git ignores it), then
run:

```sh
Benchmarks/run-decode-benchmark
```

or name the folders or files to read:

```sh
Benchmarks/run-decode-benchmark ~/Pictures/SomeFolder
```

Run it outside Claude's sandbox. Inside it, reads take about twice as long.

## Findings

These are the measurements behind the image sizes the app reads. All were
taken on a 14-inch M1 MacBook Pro with 32 GB of memory running macOS 27.2,
over Fuji X-T5 photos: RAFs, and JPEGs shot without RAW. An X-T5 original
is 7728 × 5152 (40 MP, about 160 MB decoded). Each RAF embeds a
4416 × 2944 JPEG preview (13 MP, about 52 MB decoded), which is what the
app reads for a RAW. Times are medians of five runs with the files in the
disk cache. Compare times within one run only: the runs on different days
came out at different speeds.

### Reads and draws (3 November 2026)

Read is the background work; draw is the first draw into a bitmap of the
same size.

| Read | RAF: size | RAF: read | RAF: draw | JPEG: size | JPEG: read | JPEG: draw |
|---|---|---|---|---|---|---|
| Full size, as the app read it then | 4416 × 2944 | 100–145 ms | 20 ms | 7728 × 5152 | 385 ms | 65 ms |
| Thumbnail, 520 px | 520 px | 40 ms | 0 ms | 520 px | 145 ms | 0 ms |
| Thumbnail, 2048 px | 2048 px | 75–160 ms | 4 ms | 2048 px | 250 ms | 4 ms |
| Whole image decoded | 7728 × 5152 | 2 ms | 280 ms | 7728 × 5152 | 265 ms | 95 ms |

- **A JPEG on its own costs about three or four times as much as a RAF**
  at every size, since it decodes the 40 MP original rather than the
  13 MP preview. A folder of JPEGs is where loading strains first.
- **The app's reads decode in the background.** Their draws are no
  slower than drawing an image known to be decoded already.
- **Portrait RAFs read more slowly** (145 ms against about 100 ms at full
  size), probably from rotating.
- **A RAW decoded in full takes about 280 ms**, all of it put off until
  the first draw. That's quick enough for 100% zoom, as long as the zoom
  decodes in the background.

### Why full images are at most 4416 px

Traces of stepping through JPEGs at full size showed main thread hangs.
The cause is preparing each image for display: copying the pixels,
converting them to the display's colour space, and adding an alpha
channel, since ImageIO decodes JPEGs at 3 bytes a pixel. SwiftUI does
this on a background thread, about 100 ms for a 30 MP image, and the main
thread waits for it. On a screen drawing at 6720 × 4480 that was a hang
of 100–200 ms; on one drawing at 3600 × 2400 it stayed under the 100 ms
Instruments counts as a hang.

So a full image is no more than 4416 px on its long side, the size of an
X-T5 RAF's preview, which is sharp enough even on the big screen. Each
format is read at its cheapest size under that:

| Long side | JPEG read | RAF read |
|---|---|---|
| 3600 px | 250 ms | 135 ms |
| 3864 px, half a JPEG | 200 ms | 140 ms |
| 3865 px | 400 ms | 145 ms |
| 4416 px, a RAF's preview | 420 ms | 80 ms |

- **A RAW's full image is its preview as it is,** 13 MP, about 52 MB.
  Anything smaller needs a resize.
- **A JPEG's is its own size halved until it fits,** 3864 × 2576 for an
  X-T5, 10 MP, about 40 MB. The decoder reads a half, a quarter, or an
  eighth of the image cheaply, but a pixel over and it decodes all
  40 MP and scales them down, taking twice as long.

Preparing a full image takes 35–45 ms: no longer a hang, but a few
dropped frames. If stepping stutters, the next thing to try is converting
each image to the display's format in the background, after decoding.

### The decoder's cheap sizes (6 November 2026)

| Long side asked for | JPEG read | RAF read, landscape |
|---|---|---|
| 483–966 px, an eighth of a JPEG or less | 136 ms | 20–25 ms |
| 967 px | 68 ms | 25 ms |
| 1104 px, a quarter of a RAF's preview | 70 ms | 20 ms |
| 1105 px | 70 ms | 35 ms |
| 1932 px, a quarter of a JPEG | 62 ms | 41 ms |
| 1933 px | 100 ms | 42 ms |
| 2048 px | 102 ms | 42 ms |
| 2208 px, half a RAF's preview | 105 ms | 77 ms |
| 967 px, shrunk to 520 px | 70 ms | |
| 1932 px, shrunk to 520 px | 68 ms | |

- **A JPEG read at an eighth of its size or less is the slowest read of
  all,** twice the cost of one a pixel larger. A 520-pixel thumbnail
  lands there.
- **A JPEG reads cheapest at a quarter,** and nearly as cheaply anywhere
  above an eighth. A pixel over a quarter costs 60% more.
- **Shrinking is nearly free:** 3 ms from 967 px, 7 ms from 1932 px.

So a JPEG thumbnail at an eighth of the image's size or less is read at a
quarter of it, then shrunk to the size asked for: about 70 ms rather than
136 ms, for the same image. RAFs have nothing to gain, since their
thumbnails already take 20 ms.

### Tile sizes (7 November 2026)

Reads between 1024 px and the full image, each read directly:

| Long side asked for | JPEG | RAW, landscape | RAW, portrait |
|---|---|---|---|
| 1024 px | 69 ms | 25 ms | 29 ms |
| 1932 px, a quarter of a JPEG | 62 ms | 41 ms | 82 ms |
| 2048 px | 104 ms | 42 ms | 98 ms |
| 2400–3400 px | 108–119 ms | 81–96 ms | 94–148 ms |
| The full image | 72 ms | 41 ms | 77 ms |

- **Above about 2000 px, every size costs more than the full image.**
- **Reading at a cheap size then shrinking doesn't pay at these sizes.**
  Shrinking a large image costs 10–80 ms, as much as the read saves or
  more.
- **1932 px is a JPEG's cheapest read,** 40% cheaper than 2048 px, and
  costs a RAW the same.

So a tile shows the smallest of three images at least as long as the
tile's longest side in pixels: the 520-pixel thumbnail, the 1932-pixel
medium image, or the full image. The medium image isn't simply the full
image for every tile because preparing a full image for display takes
35–45 ms, so a group of twenty would cost about a second.

### A small image cache (7 November 2026)

`ImageCache`'s NSCache has no limit, so it evicts only when macOS is
short of memory. To see how the app copes with eviction, the cache was
capped at 100 MB of decoded images for a try in the app: room for about
140 thumbnails, but only one or two full images.

The app stayed usable. Images were read again on switching screens, but
nothing kept reloading over and over, and stepping and scrolling stayed
quick. So the cache keeps no limit: eviction under memory pressure costs
some reads again, not a stuck or broken app.
