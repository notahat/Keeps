@testable import Keeps
import Testing

struct ImageSizeTests {
    @Test("A frame as long as a thumbnail shows the thumbnail")
    func thumbnailAtItsLength() {
        #expect(ImageSize.choose(forLongestSideLength: 520) == .thumbnail)
    }

    @Test("A frame shorter than a thumbnail shows the thumbnail")
    func thumbnailBelowItsLength() {
        #expect(ImageSize.choose(forLongestSideLength: 260) == .thumbnail)
    }

    @Test("A frame a fraction of a pixel longer than a thumbnail shows the medium image")
    func mediumImageJustAboveThumbnail() {
        #expect(ImageSize.choose(forLongestSideLength: 520.5) == .mediumImage)
    }

    @Test("A frame as long as the medium image shows the medium image")
    func mediumImageAtItsLength() {
        #expect(ImageSize.choose(forLongestSideLength: 1932) == .mediumImage)
    }

    @Test("A frame a fraction of a pixel longer than the medium image shows the full image")
    func fullImageJustAboveMediumImage() {
        #expect(ImageSize.choose(forLongestSideLength: 1932.5) == .full)
    }

    @Test("A frame far longer than the medium image shows the full image")
    func fullImageForLargeFrames() {
        #expect(ImageSize.choose(forLongestSideLength: 6000) == .full)
    }
}
