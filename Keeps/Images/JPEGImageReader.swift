import CoreGraphics
import ImageIO

/// Reads a JPEG file's image by decoding the image itself. The JPEG decoder
/// is much quicker at some sizes than others, so the reads pick their sizes
/// to suit it, as measured with Benchmarks/run-decode-benchmark. It holds no
/// state, so all its methods are safe to call from any thread.
enum JPEGImageReader {
    /// When a JPEG file is read as a full image, it's scaled down so its
    /// longest side is no more than this many pixels. The limit matches the
    /// JPEG preview a Fuji X-T5 embeds in its RAW files, which looks sharp
    /// enough even on a large external screen.
    /// Reading JPEG files in full, at 40 MP, makes Core Animation pause the
    /// main thread each time one first shows.
    private nonisolated static let maxFullImageLongestSideLength = 4416

    /// Read a JPEG file's image at a size.
    nonisolated static func image(from source: CGImageSource, size: ImageSize) -> CGImage? {
        switch size {
        case let .scaled(targetLongestSideLength):
            scaledImage(from: source, targetLongestSideLength: targetLongestSideLength)
        case .full: fullImage(from: source)
        }
    }

    /// Read a JPEG file's scaled image.
    private nonisolated static func scaledImage(
        from source: CGImageSource,
        targetLongestSideLength: Int
    ) -> CGImage? {
        guard let imageLongestSideLength = longestSideLength(of: source) else { return nil }
        if targetLongestSideLength <= imageLongestSideLength / 8 {
            // If the target side length is an eighth of the image's or less,
            // load it at a quarter of the image's size, then shrink it.
            // That's twice as fast as loading it directly at the target size.
            guard let image = readScaledImage(from: source, targetLongestSideLength: imageLongestSideLength / 4) else { return nil }
            return shrink(image, toLongestSideLength: targetLongestSideLength)
        } else {
            // ...otherwise load it directly at the target size.
            return readScaledImage(from: source, targetLongestSideLength: targetLongestSideLength)
        }
    }

    /// Read a JPEG file's full image.
    private nonisolated static func fullImage(from source: CGImageSource) -> CGImage? {
        guard let imageLongestSideLength = longestSideLength(of: source) else { return nil }
        // Load it at the image's size halved until it fits the limit. Loading
        // at exactly a half takes half the time of a size a pixel larger.
        let readLongestSideLength = halvedSize(
            of: imageLongestSideLength,
            toAtMost: maxFullImageLongestSideLength
        )
        return readScaledImage(from: source, targetLongestSideLength: readLongestSideLength)
    }

    /// Halve an image's longest side length until it's no more than the
    /// limit, rounding down, and return the result. A JPEG file's full
    /// image is read at this length, since its decoder reads exactly a half
    /// of the image cheaply, but a pixel more costs twice as much.
    nonisolated static func halvedSize(of imageLongestSideLength: Int, toAtMost limit: Int) -> Int {
        var length = imageLongestSideLength
        while length > limit {
            length /= 2
        }
        return length
    }

    /// Read a JPEG file's image, scaled so its longest side is no more than
    /// the target length.
    private nonisolated static func readScaledImage(
        from source: CGImageSource,
        targetLongestSideLength: Int
    ) -> CGImage? {
        let options: [CFString: Any] = [
            // Always scale from the full image rather than using a smaller
            // embedded preview.
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetLongestSideLength,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Shrink an image so its longest side is a given length, by drawing it
    /// into a smaller bitmap with high quality interpolation, returning nil
    /// if the bitmap can't be made. The image keeps its colour space
    /// when that's RGB, and is converted to sRGB otherwise, since the
    /// bitmap has no other layout to suit a grey or CMYK one.
    private nonisolated static func shrink(_ image: CGImage, toLongestSideLength targetLongestSideLength: Int) -> CGImage? {
        let scale = Double(targetLongestSideLength) / Double(max(image.width, image.height))
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))
        let colorSpace = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil }
            ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
        context?.interpolationQuality = .high
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context?.makeImage()
    }

    /// Read the length in pixels of the longest side of a file's image. The
    /// length comes from the file's header, so the image isn't decoded.
    /// Return nil if the header doesn't give it.
    private nonisolated static func longestSideLength(of source: CGImageSource) -> Int? {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        guard let width = properties?[kCGImagePropertyPixelWidth] as? Int,
              let height = properties?[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return max(width, height)
    }
}
