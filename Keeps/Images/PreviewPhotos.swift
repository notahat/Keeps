import Foundation

/// Photos for SwiftUI previews: PhotoItems for the JPEGs in Preview Content,
/// with their thumbnails already in the image pipeline's cache, so previews
/// draw them straight away. Release builds leave Preview Content out, so
/// nothing outside a preview may use these.
@MainActor
enum PreviewPhotos {
    /// A landscape photo.
    static let landscape = makeItem(fileName: "preview-landscape", stem: "PREVIEW_LANDSCAPE")

    /// A portrait photo.
    static let portrait = makeItem(fileName: "preview-portrait", stem: "PREVIEW_PORTRAIT")

    /// Makes the given number of photos, alternating landscape and portrait.
    /// Each has its own stem, so in a pile each print is tilted differently.
    static func makeItems(count: Int) -> [PhotoItem] {
        (1 ... count).map { index in
            let fileName = index.isMultiple(of: 2) ? "preview-portrait" : "preview-landscape"
            return makeItem(fileName: fileName, stem: String(format: "PREVIEW_%04d", index))
        }
    }

    /// Makes a photo for one of the preview JPEGs and caches its thumbnail,
    /// failing if the file is missing from the bundle.
    private static func makeItem(fileName: String, stem: String) -> PhotoItem {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "jpg") else {
            fatalError("Missing preview photo \(fileName).jpg")
        }
        let item = PhotoItem(id: UUID(), stem: stem, rawURL: nil, jpegURL: url, capturedAt: .now)
        ImagePipeline.shared.loadImageImmediately(for: item, size: ThumbnailImage.imageSize)
        return item
    }
}
