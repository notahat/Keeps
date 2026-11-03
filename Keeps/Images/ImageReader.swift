import AppKit
import ImageIO

/// Pure functions for reading images from files using CGImageSource. All
/// methods are safe to call from any thread.
///
/// Every read is scaled down. A thumbnail is read at the size it names. A
/// full image is read at whichever size near `ImageSize.full`'s limit is
/// cheapest for the file's format (see fullImageMaxPixelSize).
enum ImageReader {
    /// Reads a photo's image at a size, or nil if the file can't be read.
    nonisolated static func image(from url: URL, size: ImageSize) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let isJPEG = isJPEG(url)
        let maxPixelSize = switch size {
        case let .thumbnail(maxPixelSize): maxPixelSize
        case .full: fullImageMaxPixelSize(of: source, isJPEG: isJPEG)
        }
        return scaledImage(from: source, isJPEG: isJPEG, maxPixelSize: maxPixelSize)
    }

    /// The longest side a pixel size reaches by halving it until it's no
    /// more than the limit, rounding down. A JPEG decoder can decode at
    /// half, a quarter, or an eighth of the size for much less than the
    /// whole image, but only at or below those sizes: a pixel more and it
    /// decodes the whole image and then scales it down, which takes about
    /// twice as long.
    nonisolated static func halvedSize(of longestSide: Int, toAtMost limit: Int) -> Int {
        var size = longestSide
        while size > limit {
            size /= 2
        }
        return size
    }

    /// The longest side to read a photo's full image at. A RAW's embedded
    /// JPEG preview is read at the limit, which is the X-T5's preview size,
    /// so it comes back as it is with nothing to scale. A JPEG is read at
    /// a halving of its own size, which it decodes cheaply.
    private nonisolated static func fullImageMaxPixelSize(of source: CGImageSource, isJPEG: Bool) -> Int {
        let limit = ImageSize.fullImageMaxPixelSize
        guard isJPEG, let longestSide = longestSide(of: source) else { return limit }
        return halvedSize(of: longestSide, toAtMost: limit)
    }

    /// Reads an image scaled down to fit a square of the given size. For a
    /// JPEG it decodes the image itself, rather than the tiny blurry
    /// thumbnail embedded in the file. For a RAW it scales the embedded
    /// JPEG preview, which is much quicker than decoding the RAW data.
    /// kCGImageSourceCreateThumbnailWithTransform applies the EXIF
    /// orientation, so portrait shots display upright with no extra
    /// rotation.
    private nonisolated static func scaledImage(
        from source: CGImageSource,
        isJPEG: Bool,
        maxPixelSize: Int
    ) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: isJPEG,
            kCGImageSourceCreateThumbnailFromImageIfAbsent: !isJPEG,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// The longest side of the image in a file, in pixels, from its header,
    /// or nil if the header doesn't say.
    private nonisolated static func longestSide(of source: CGImageSource) -> Int? {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        guard let width = properties?[kCGImagePropertyPixelWidth] as? Int,
              let height = properties?[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return max(width, height)
    }

    /// Whether a file is a JPEG, going by its extension.
    private nonisolated static func isJPEG(_ url: URL) -> Bool {
        ["jpg", "jpeg"].contains(url.pathExtension.lowercased())
    }
}
