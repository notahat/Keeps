import AppKit
import ImageIO

/// Reads photos from files as images scaled to the size the app wants
/// (`ImageSize`). It holds no state, so all its methods are safe to call
/// from any thread.
///
/// A RAW file's image comes from the JPEG preview the camera embeds in it,
/// which is far quicker than decoding the sensor data. A JPEG file's image
/// is decoded from the image itself. The JPEG decoder is much quicker at
/// some sizes than others, so the JPEG reads pick their sizes to suit it,
/// as measured with Benchmarks/run-decode-benchmark.
///
/// Every read applies the photo's EXIF orientation, so portrait shots come
/// out upright.
enum ImageReader {
    /// When a JPEG file is read as a full image, it's scaled down so its
    /// longest side is no more than this many pixels. The limit matches the
    /// JPEG preview a Fuji X-T5 embeds in its RAW files, which looks sharp
    /// enough even on a large external screen.
    /// Reading JPEG files in full, at 40 MP, makes Core Animation pause the
    /// main thread each time one first shows.
    private nonisolated static let maxFullImageLongestSideLength = 4416

    /// Read a photo's image at a size, returning nil if the file can't be
    /// read.
    nonisolated static func image(from url: URL, size: ImageSize) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return isJPEG(url) ? jpegImage(from: source, size: size) : rawImage(from: source, size: size)
    }

    /// Read a RAW file's image at a size.
    private nonisolated static func rawImage(from source: CGImageSource, size: ImageSize) -> CGImage? {
        switch size {
        case let .thumbnail(targetLongestSideLength):
            rawThumbnail(from: source, targetLongestSideLength: targetLongestSideLength)
        case .full: rawFull(from: source)
        }
    }

    /// Read a JPEG file's image at a size.
    private nonisolated static func jpegImage(from source: CGImageSource, size: ImageSize) -> CGImage? {
        switch size {
        case let .thumbnail(targetLongestSideLength):
            jpegThumbnail(from: source, targetLongestSideLength: targetLongestSideLength)
        case .full: jpegFull(from: source)
        }
    }

    /// Read a RAW file's thumbnail by scaling its embedded JPEG preview
    /// straight to the size asked for. At thumbnail sizes that takes about
    /// 20 ms.
    private nonisolated static func rawThumbnail(
        from source: CGImageSource,
        targetLongestSideLength: Int
    ) -> CGImage? {
        readScaledRAW(from: source, targetLongestSideLength: targetLongestSideLength)
    }

    /// Read a RAW file's embedded JPEG preview, at the preview's own size.
    private nonisolated static func rawFull(from source: CGImageSource) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Read a JPEG file's thumbnail.
    private nonisolated static func jpegThumbnail(
        from source: CGImageSource,
        targetLongestSideLength: Int
    ) -> CGImage? {
        guard let imageLongestSideLength = longestSideLength(of: source) else { return nil }
        if targetLongestSideLength <= imageLongestSideLength / 8 {
            // If the target side length is an eighth of the image's or less,
            // load it at a quarter of the image's size, then shrink it.
            // That's twice as fast as loading it directly at the target size.
            guard let image = readScaledJPEG(from: source, targetLongestSideLength: imageLongestSideLength / 4) else { return nil }
            return shrink(image, toLongestSideLength: targetLongestSideLength)
        } else {
            // ...otherwise load it directly at the target size.
            return readScaledJPEG(from: source, targetLongestSideLength: targetLongestSideLength)
        }
    }

    /// Read a JPEG file's full image.
    private nonisolated static func jpegFull(from source: CGImageSource) -> CGImage? {
        guard let imageLongestSideLength = longestSideLength(of: source) else { return nil }
        // Load it at the image's size halved until it fits the limit. Loading
        // at exactly a half takes half the time of a size a pixel larger.
        let readLongestSideLength = halvedSize(
            of: imageLongestSideLength,
            toAtMost: maxFullImageLongestSideLength
        )
        return readScaledJPEG(from: source, targetLongestSideLength: readLongestSideLength)
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

    /// Read a RAW file's embedded JPEG preview, scaled so its longest side is no
    /// more than the target length.
    private nonisolated static func readScaledRAW(
        from source: CGImageSource,
        targetLongestSideLength: Int
    ) -> CGImage? {
        let options: [CFString: Any] = [
            // Fall back to generating the image from the RAW if there's no embedded JPEG.
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetLongestSideLength,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Read a JPEG file's image, scaled so its longest side is no more than the
    /// target length.
    private nonisolated static func readScaledJPEG(
        from source: CGImageSource,
        targetLongestSideLength: Int
    ) -> CGImage? {
        let options: [CFString: Any] = [
            // Always scale from the full image rather than using a smaller embedded preview.
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

    /// Return true if a file is a JPEG, going by its extension.
    private nonisolated static func isJPEG(_ url: URL) -> Bool {
        ["jpg", "jpeg"].contains(url.pathExtension.lowercased())
    }
}
