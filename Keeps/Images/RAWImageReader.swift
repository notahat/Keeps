import ImageIO

/// Reads a RAW file's image from the JPEG preview the camera embeds in it,
/// which is far quicker than decoding the sensor data. It holds no state, so
/// all its methods are safe to call from any thread.
enum RAWImageReader {
    /// Read a RAW file's image at a size.
    nonisolated static func readImage(from source: CGImageSource, size: ImageSize) -> CGImage? {
        switch size {
        case let .scaled(targetLongestSideLength):
            readScaledImage(from: source, targetLongestSideLength: targetLongestSideLength)
        case .full: readFullImage(from: source)
        }
    }

    /// Read a RAW file's scaled image by scaling its embedded JPEG preview
    /// straight to the size asked for. A thumbnail takes about 20 ms.
    private nonisolated static func readScaledImage(
        from source: CGImageSource,
        targetLongestSideLength: Int
    ) -> CGImage? {
        let options: [CFString: Any] = [
            // Fall back to generating the image from the RAW data if there's
            // no embedded JPEG.
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetLongestSideLength,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Read a RAW file's embedded JPEG preview, at the preview's own size.
    private nonisolated static func readFullImage(from source: CGImageSource) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
