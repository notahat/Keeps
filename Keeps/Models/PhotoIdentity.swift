import CryptoKit
import Foundation

extension UUID {
    /// Derives a stable UUID from a folder URL and photo stem so that the same
    /// photo always gets the same identity across app restarts.
    static func forPhoto(folderURL: URL, stem: String) -> UUID {
        let input = folderURL.absoluteString + "\0" + stem
        let hash = SHA256.hash(data: Data(input.utf8))
        var bytes = Array(hash.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50 // UUID version 5
        bytes[8] = (bytes[8] & 0x3F) | 0x80 // UUID variant
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
