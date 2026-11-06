import Foundation
import ImageIO

/// Times ImageReader's reads over sample photos, to show what each kind of
/// read costs and what size of image it gives back. It's compiled together
/// with the app's ImageReader.swift and ImageSize.swift (see
/// run-decode-benchmark), so it times the app's own code, at the sizes
/// the app reads.
///
/// Each read is timed in two parts:
///
/// - Read is the call that gives back a CGImage, which is what the app's
///   image pipeline does off the main thread.
/// - Draw is drawing that image once into a bitmap of its own size. A
///   CGImage can put off decoding until it's first drawn, which in the app
///   happens on the main thread. Drawing costs something even once the
///   image is decoded, so compare with the whole image decoded row, whose
///   read always decodes: a draw much slower than that one means the read
///   left the decoding for later.
///
/// Each read runs several times and the median is reported. The files are
/// in the disk cache after the first run, so the times are for decoding,
/// not for reading the disk. Reading the files and measuring are the only
/// things it does; it changes nothing.
@main
enum DecodeBenchmark {
    /// How many times each read runs.
    static let runCount = 5

    /// The file extensions of the photos the app reads.
    static let photoExtensions: Set = ["raf", "jpg", "jpeg"]

    /// Benchmarks every photo in the folders or files named on the command
    /// line.
    static func main() {
        let paths = CommandLine.arguments.dropFirst()
        let urls = paths.flatMap { photoURLs(at: URL(filePath: $0)) }
        guard !urls.isEmpty else {
            print("No photos found in \(paths.joined(separator: ", ")).")
            exit(1)
        }
        let reads = Read.all
        for url in urls {
            benchmark(url, reads: reads)
        }
    }

    /// The photos at a path: the file itself, or the photos in a folder,
    /// sorted by name.
    static func photoURLs(at url: URL) -> [URL] {
        let contents = try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil
        )
        guard let contents else { return [url] }
        return contents
            .filter { photoExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Times each read of one photo, and prints a table of them.
    static func benchmark(_ url: URL, reads: [Read]) {
        print("\n\(url.lastPathComponent)")
        print(row("Read", "Size", "Read", "Draw"))
        for read in reads {
            print(measure(read, of: url))
        }
    }

    /// One row of the table, with the columns lined up.
    static func row(_ name: String, _ size: String, _ readTime: String, _ drawTime: String) -> String {
        let columns = [
            name.padding(toLength: 28, withPad: " ", startingAt: 0),
            size.padding(toLength: 11, withPad: " ", startingAt: 0),
            readTime.leftPadded(toLength: 8),
            drawTime.leftPadded(toLength: 8),
        ]
        return "  " + columns.joined(separator: "  ")
    }

    /// Runs a read of a photo several times, and gives back its table row:
    /// the size of image it gave and its median read and draw times.
    static func measure(_ read: Read, of url: URL) -> String {
        var readTimes: [Duration] = []
        var drawTimes: [Duration] = []
        var size = "failed"
        for _ in 0 ..< runCount {
            let clock = ContinuousClock()
            var image: CGImage?
            readTimes.append(clock.measure { image = read.perform(url) })
            guard let image else { return row(read.name, size, "–", "–") }
            drawTimes.append(clock.measure { draw(image) })
            size = "\(image.width) × \(image.height)"
        }
        return row(read.name, size, milliseconds(median(readTimes)), milliseconds(median(drawTimes)))
    }

    /// Draws an image once into a new bitmap of its own size, which decodes
    /// it if the read didn't.
    static func draw(_ image: CGImage) {
        let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }

    /// The middle of some times, or the lower of the middle two.
    static func median(_ times: [Duration]) -> Duration {
        times.sorted()[(times.count - 1) / 2]
    }

    /// A time in whole milliseconds, such as "42 ms".
    static func milliseconds(_ duration: Duration) -> String {
        let (seconds, attoseconds) = duration.components
        return "\(seconds * 1000 + attoseconds / 1_000_000_000_000_000) ms"
    }
}

/// One kind of read the benchmark times, with the name it shows in the
/// table.
struct Read: Sendable {
    let name: String
    let perform: @Sendable (URL) -> CGImage?

    /// The reads the app makes, then a decode of the whole image, which
    /// the app doesn't do yet but 100% zoom would need, then reads at the
    /// steps a JPEG decoder takes cheaply.
    static let all: [Read] = [
        app("Full size view", size: .full),
        app("Thumbnail, 520 px", size: .thumbnail(maxPixelSize: 520)),
        app("Tile, 2048 px", size: .thumbnail(maxPixelSize: 2048)),
        Read(name: "Whole image decoded") { decodeWholeImage(from: $0) },
    ] + decoderSteps + shrinks

    /// Reads at a size a JPEG decoder takes cheaply, then shrinks the image
    /// to the thumbnail size, timed together. Compare with the 520 px
    /// thumbnail read, which gives the same image.
    static let shrinks: [Read] = [967, 1932].map { pixelSize in
        Read(name: "At \(pixelSize), shrunk to 520") { url in
            let image = ImageReader.image(from: url, size: .thumbnail(maxPixelSize: pixelSize))
            return image.flatMap { shrink($0, toFit: 520) }
        }
    }

    /// Reads at the sizes either side of a half, a quarter, and an eighth
    /// of an X-T5 JPEG (7728 px) and of an X-T5 RAF's preview (4416 px).
    /// A JPEG decoder reads those fractions cheaply, so comparing a step
    /// with the pixel above it shows whether a read at that size gains
    /// from landing on the step.
    static let decoderSteps: [Read] = [
        483, 520, 552, 553, 966, 967, 1104, 1105, 1932, 1933, 2048, 2208, 2209,
    ].map { pixelSize in
        app("At \(pixelSize) px", size: .thumbnail(maxPixelSize: pixelSize))
    }

    /// A read the app makes, of an image at a size.
    static func app(_ name: String, size: ImageSize) -> Read {
        Read(name: name) { ImageReader.image(from: $0, size: size) }
    }

    /// Shrinks an image so its longest side is a given size, by drawing it
    /// into a smaller bitmap with high quality interpolation. Gives back
    /// nil if the bitmap can't be made.
    static func shrink(_ image: CGImage, toFit maxPixelSize: Int) -> CGImage? {
        let scale = Double(maxPixelSize) / Double(max(image.width, image.height))
        let width = Int((Double(image.width) * scale).rounded())
        let height = Int((Double(image.height) * scale).rounded())
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
        context?.interpolationQuality = .high
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context?.makeImage()
    }

    /// Decodes the image itself in full, rather than any preview: for a RAW,
    /// the sensor data. Decoding happens straight away, so the draw that
    /// follows doesn't include it.
    static func decodeWholeImage(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
        return CGImageSourceCreateImageAtIndex(source, 0, options)
    }
}

extension String {
    /// The string with spaces in front to make it a given length.
    func leftPadded(toLength length: Int) -> String {
        String(repeating: " ", count: max(0, length - count)) + self
    }
}
