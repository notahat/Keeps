import CoreFoundation
@testable import Keeps
import Testing

@MainActor
struct ThumbnailImageTests {
    @Test("A frame as long as a thumbnail shows the thumbnail")
    func thumbnailAtItsLength() {
        #expect(ThumbnailImage.chooseImageSize(forLongestSideLength: 520) == ThumbnailImage.imageSize)
    }

    @Test("A frame shorter than a thumbnail shows the thumbnail")
    func thumbnailBelowItsLength() {
        #expect(ThumbnailImage.chooseImageSize(forLongestSideLength: 260) == ThumbnailImage.imageSize)
    }

    @Test("A frame a fraction of a pixel longer than a thumbnail shows the tile image")
    func tileImageJustAboveThumbnail() {
        #expect(ThumbnailImage.chooseImageSize(forLongestSideLength: 520.5) == .tile)
    }

    @Test("A frame as long as the tile image shows the tile image")
    func tileImageAtItsLength() {
        #expect(ThumbnailImage.chooseImageSize(forLongestSideLength: 1932) == .tile)
    }

    @Test("A frame a fraction of a pixel longer than the tile image shows the full image")
    func fullImageJustAboveTileImage() {
        #expect(ThumbnailImage.chooseImageSize(forLongestSideLength: 1932.5) == .full)
    }

    @Test("A frame far longer than the tile image shows the full image")
    func fullImageForLargeFrames() {
        #expect(ThumbnailImage.chooseImageSize(forLongestSideLength: 6000) == .full)
    }
}
