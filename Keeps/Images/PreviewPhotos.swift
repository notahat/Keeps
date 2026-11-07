import Foundation

/// Photos for SwiftUI previews: PhotoItems for the JPEGs in Preview Content,
/// with their thumbnails already in the image pipeline's cache, so previews
/// draw them straight away. Release builds leave Preview Content out, so
/// nothing outside a preview may use these.
@MainActor
enum PreviewPhotos {
    /// A landscape photo.
    static let landscape = makePhoto(fileName: "preview-landscape", stem: "PREVIEW_LANDSCAPE")

    /// A portrait photo.
    static let portrait = makePhoto(fileName: "preview-portrait", stem: "PREVIEW_PORTRAIT")

    /// Make the given number of photos, alternating landscape and portrait.
    /// Each has its own stem, so in a pile each print is tilted differently.
    static func makePhotos(count: Int) -> [PhotoItem] {
        (1 ... count).map { index in
            let fileName = index.isMultiple(of: 2) ? "preview-portrait" : "preview-landscape"
            return makePhoto(fileName: fileName, stem: String(format: "PREVIEW_%04d", index))
        }
    }

    /// Make a photo for one of the preview JPEGs and cache its thumbnail,
    /// stopping with a fatal error if the file is missing from the bundle.
    private static func makePhoto(fileName: String, stem: String) -> PhotoItem {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "jpg") else {
            fatalError("Missing preview photo \(fileName).jpg")
        }
        let photo = PhotoItem(id: UUID(), stem: stem, rawURL: nil, jpegURL: url, fileCreationDate: .now)
        ImagePipeline.shared.loadImageImmediately(for: photo, size: .thumbnail)
        return photo
    }
}
