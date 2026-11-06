import CoreFoundation
@testable import Keeps
import Testing

@MainActor
struct FramedPhotoTests {
    @Test("A frame as long as a thumbnail shows the thumbnail")
    func thumbnailAtItsLength() {
        #expect(FramedPhoto.chooseImageSize(forLongestSideLength: 520) == FramedPhoto.thumbnailSize)
    }

    @Test("A frame shorter than a thumbnail shows the thumbnail")
    func thumbnailBelowItsLength() {
        #expect(FramedPhoto.chooseImageSize(forLongestSideLength: 260) == FramedPhoto.thumbnailSize)
    }

    @Test("A frame a fraction of a pixel longer than a thumbnail shows the medium image")
    func mediumImageJustAboveThumbnail() {
        #expect(FramedPhoto.chooseImageSize(forLongestSideLength: 520.5) == FramedPhoto.mediumImageSize)
    }

    @Test("A frame as long as the medium image shows the medium image")
    func mediumImageAtItsLength() {
        #expect(FramedPhoto.chooseImageSize(forLongestSideLength: 1932) == FramedPhoto.mediumImageSize)
    }

    @Test("A frame a fraction of a pixel longer than the medium image shows the full image")
    func fullImageJustAboveMediumImage() {
        #expect(FramedPhoto.chooseImageSize(forLongestSideLength: 1932.5) == .full)
    }

    @Test("A frame far longer than the medium image shows the full image")
    func fullImageForLargeFrames() {
        #expect(FramedPhoto.chooseImageSize(forLongestSideLength: 6000) == .full)
    }
}
