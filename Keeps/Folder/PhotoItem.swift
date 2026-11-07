import Foundation

/// One photo in the open folder: a RAW file, a JPEG file, or a RAW and a
/// JPEG that share a stem (the file name without its extension), which
/// count as one photo. The code calls these photos throughout. At least one
/// of rawURL and jpegURL is always set.
///
/// A photo has two identities. `id` names it in memory, and is made afresh
/// each time FolderScanner scans the folder, so it means nothing after the
/// folder is closed. `stem`, such as "IMG_001", names it in keeps.json,
/// because only the stem still picks out the same photo when the folder is
/// scanned again. Grouping translates between the two when it converts to
/// and from SavedGrouping.
struct PhotoItem: Identifiable {
    /// The photo's in-memory identity, unique within one scan.
    let id: UUID

    /// The file name without its extension, shared by both files of a pair.
    let stem: String

    /// The RAW file, or nil for a JPEG on its own.
    let rawURL: URL?

    /// The JPEG file, or nil for a RAW file on its own.
    let jpegURL: URL?

    /// The creation date of the photo's JPEG file, or of its RAW file when
    /// it has no JPEG, which sets the photos' order. For photos straight off
    /// a camera card, this is close to when each was taken.
    let fileCreationDate: Date

    /// The file to read images from and to drag: the RAW file when there is
    /// one, so its embedded JPEG preview can be read, otherwise the JPEG.
    var sourceURL: URL {
        // Safe: every PhotoItem has at least one URL (see above).
        // swiftlint:disable:next force_unwrapping
        rawURL ?? jpegURL!
    }
}
