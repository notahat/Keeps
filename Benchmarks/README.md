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

The results for the user's samples are recorded in PLAN.md.
