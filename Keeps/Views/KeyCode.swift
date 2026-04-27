import AppKit

/// Named constants for virtual key codes used in keyboard navigation.
/// Raw values are macOS virtual key codes from HIToolbox/Events.h.
extension UInt16 {
    static let returnKey: UInt16 = 36
    static let escape: UInt16 = 53
    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
    static let downArrow: UInt16 = 125
    static let upArrow: UInt16 = 126
}
