import Foundation
import ImageIO
@testable import Keeps
import Testing
import UniformTypeIdentifiers

struct ImageReaderTests {
    @Test("A small scaled JPEG image comes back at the size asked for, upright")
    func readsSmallScaledImageUpright() throws {
        let url = try writeJPEG(width: 400, height: 200, orientation: .right)
        defer { try? FileManager.default.removeItem(at: url) }

        let image = try #require(ImageReader.readImage(from: url, size: .scaled(longestSideLength: 40)))

        #expect(image.width == 20)
        #expect(image.height == 40)
    }

    /// Write a plain grey JPEG of a given size in pixels to a new temporary
    /// file, tagged with an EXIF orientation, and return its URL. The caller
    /// removes the file.
    private func writeJPEG(width: Int, height: Int, orientation: CGImagePropertyOrientation) throws -> URL {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(gray: 0.5, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let url = FileManager.default.temporaryDirectory
            .appending(path: "\(UUID().uuidString).jpg")
        let destination = try #require(
            CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        )
        let properties = [kCGImagePropertyOrientation: orientation.rawValue] as CFDictionary
        CGImageDestinationAddImage(destination, image, properties)
        try #require(CGImageDestinationFinalize(destination))
        return url
    }
}
