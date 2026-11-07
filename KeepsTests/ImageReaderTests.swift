import Foundation
import ImageIO
@testable import Keeps
import Testing
import UniformTypeIdentifiers

struct ImageReaderTests {
    @Test("A small scaled JPEG image comes back at the size asked for, upright")
    func readsSmallScaledImageUpright() throws {
        let url = try writeJPEG(width: 400, height: 200, orientation: .right)

        let image = ImageReader.readImage(from: url, size: .scaled(longestSideLength: 40))

        #expect(image?.width == 20)
        #expect(image?.height == 40)
    }

    /// Writes a plain grey JPEG of a given size to a new temporary file,
    /// tagged with an EXIF orientation, and gives back its URL.
    private func writeJPEG(width: Int, height: Int, orientation: CGImagePropertyOrientation) throws -> URL {
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
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
        #expect(CGImageDestinationFinalize(destination))
        return url
    }
}
