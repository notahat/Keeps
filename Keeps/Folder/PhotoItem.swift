import Foundation

/// Represents one photo in the open folder — either a standalone RAW file, a standalone
/// JPEG, or a matched RAW+JPEG pair sharing the same filename stem.
///
/// At least one of rawURL or jpegURL is always non-nil.
///
/// Photos have two identifiers that serve different purposes: `id` (UUID) is used
/// everywhere in memory; `stem` (filename without extension, e.g. "IMG_001") is
/// used in keeps.json on disk. Stems are used for persistence so that saved state
/// survives folder moves. Code that crosses the memory/disk boundary must
/// translate between them — Grouping does this when it converts to and from
/// SavedGrouping.
struct PhotoItem: Identifiable {
    let id: UUID
    let stem: String
    let rawURL: URL?
    let jpegURL: URL?

    /// The file's creation date, used for chronological sort order.
    let capturedAt: Date

    /// The URL to use for image loading. Prefers the RAW file so we can extract its
    /// embedded JPEG; falls back to a standalone JPEG.
    var sourceURL: URL {
        // swiftlint:disable:next force_unwrapping
        rawURL ?? jpegURL! // Safe: the class invariant guarantees at least one URL is non-nil.
    }
}
