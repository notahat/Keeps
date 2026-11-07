import AppKit
@testable import Keeps
import Testing

@MainActor
struct ImageCacheTests {
    @Test("Tallies the cached images and their memory at each size")
    func talliesContents() throws {
        let cache = ImageCache()
        let photos = makePhotos(count: 3)

        try cache.setImage(makeImage(width: 10, height: 5), for: photos[0], size: .full)
        try cache.setImage(makeImage(width: 4, height: 2), for: photos[1], size: .scaled(longestSideLength: 4))
        try cache.setImage(makeImage(width: 4, height: 4), for: photos[2], size: .scaled(longestSideLength: 4))

        #expect(cache.contents() == [
            ImageCache.Contents(size: .scaled(longestSideLength: 4), imageCount: 2, byteCount: (8 + 16) * 4),
            ImageCache.Contents(size: .full, imageCount: 1, byteCount: 50 * 4),
        ])
    }

    @Test("Counts an image once when it replaces one cached under the same photo and size")
    func replacingCountsOnce() throws {
        let cache = ImageCache()
        let photo = makePhotos(count: 1)[0]

        try cache.setImage(makeImage(width: 10, height: 10), for: photo, size: .full)
        try cache.setImage(makeImage(width: 2, height: 2), for: photo, size: .full)

        #expect(cache.contents() == [ImageCache.Contents(size: .full, imageCount: 1, byteCount: 4 * 4)])
    }

    @Test("Has no contents when empty")
    func emptyContents() {
        #expect(ImageCache().contents().isEmpty)
    }

    /// Make a blank image of a given size in pixels.
    private func makeImage(width: Int, height: Int) throws -> NSImage {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        return try NSImage(cgImage: #require(context.makeImage()), size: .zero)
    }
}
