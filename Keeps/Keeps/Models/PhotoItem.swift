import Foundation

/// Represents one photo in the library — either a standalone RAW file, a standalone
/// JPEG, or a matched RAW+JPEG pair sharing the same filename stem.
///
/// At least one of rawURL or jpegURL is always non-nil.
struct PhotoItem: Identifiable {
    let id: UUID
    let stem: String
    let rawURL: URL?
    let jpegURL: URL?

    /// The URL to use for image loading. Prefers the RAW file so we can extract its
    /// embedded JPEG; falls back to a standalone JPEG.
    var sourceURL: URL {
        rawURL ?? jpegURL!
    }
}
