import Foundation

/// How one photo sits in a messy pile of prints, on any screen: a small
/// rotation and offset. Derived from the photo's stem, so a pile looks the
/// same on every render and every launch. (Swift's own string hashing is
/// reseeded each launch, hence the hand-rolled hash.) It's a pure value.
nonisolated struct PileJitter: Equatable {
    /// The furthest, in degrees, a print is tilted either way.
    static let maximumRotationDegrees: Double = 8

    /// The furthest, in points, a print is nudged either way along each
    /// axis.
    static let maximumOffset: Double = 10

    /// The print's tilt, in degrees, positive clockwise.
    let rotationDegrees: Double

    /// How far, in points, the print is nudged to the right; negative for
    /// the left.
    let horizontalOffset: Double

    /// How far, in points, the print is nudged down; negative for up.
    let verticalOffset: Double

    /// Make the jitter for the photo with this stem.
    init(stem: String) {
        let hash = Self.mixedHash(of: stem)
        rotationDegrees = Self.unitValue(hash, slice: 0) * Self.maximumRotationDegrees
        horizontalOffset = Self.unitValue(hash, slice: 1) * Self.maximumOffset
        verticalOffset = Self.unitValue(hash, slice: 2) * Self.maximumOffset
    }

    /// Return an FNV-1a hash of the string, passed through the SplitMix64
    /// finaliser so that similar stems (IMG_0042, IMG_0043) still differ in
    /// every bit.
    private static func mixedHash(of string: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in string.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100_0000_01B3
        }
        hash = (hash ^ (hash >> 30)) &* 0xBF58_476D_1CE4_E5B9
        hash = (hash ^ (hash >> 27)) &* 0x94D0_49BB_1331_11EB
        return hash ^ (hash >> 31)
    }

    /// Return a value in -1...1 taken from one 16-bit slice of the hash,
    /// where `slice` counts slices from the lowest bits, from 0 to 3.
    private static func unitValue(_ hash: UInt64, slice: Int) -> Double {
        let bits = (hash >> UInt64(slice * 16)) & 0xFFFF
        return Double(bits) / Double(0xFFFF) * 2 - 1
    }
}
