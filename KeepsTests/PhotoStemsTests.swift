@testable import Keeps
import Testing

struct PhotoStemsTests {
    @Test("A point before a photo is saved by that photo's stem and read back")
    func positionBeforePhoto() {
        let stems = PhotoStems(items: makePhotoItems(count: 5))

        let position = stems.position(beforePhoto: 2)

        #expect(position == .beforePhoto("IMG_0003"))
        #expect(stems.photoIndex(at: position) == 2)
    }

    @Test("The point after the last photo is saved as the end and read back")
    func positionAtEnd() {
        let stems = PhotoStems(items: makePhotoItems(count: 5))

        let position = stems.position(beforePhoto: 5)

        #expect(position == .end)
        #expect(stems.photoIndex(at: position) == 5)
    }

    @Test("A point before a photo no longer in the folder reads back as nothing")
    func positionOfMissingPhoto() {
        let stems = PhotoStems(items: makePhotoItems(count: 5))

        #expect(stems.photoIndex(at: .beforePhoto("IMG_9999")) == nil)
    }

    @Test("A set of photos is saved as stems in folder order")
    func stemsInFolderOrder() {
        let stems = PhotoStems(items: makePhotoItems(count: 5))

        #expect(stems.stems(ofPhotos: [3, 0, 1]) == ["IMG_0001", "IMG_0002", "IMG_0004"])
    }

    @Test("No photos are saved as no entry at all")
    func noPhotosSaveNothing() {
        let stems = PhotoStems(items: makePhotoItems(count: 5))

        #expect(stems.stems(ofPhotos: []) == nil)
    }

    @Test("Stems read back as photos, dropping any no longer in the folder")
    func photosFromStems() {
        let stems = PhotoStems(items: makePhotoItems(count: 5))

        #expect(stems.photoIndices(ofStems: ["IMG_0002", "IMG_9999", "IMG_0005"]) == [1, 4])
    }

    @Test("A missing entry reads back as no photos")
    func photosFromNoEntry() {
        let stems = PhotoStems(items: makePhotoItems(count: 5))

        #expect(stems.photoIndices(ofStems: nil) == [])
    }
}
