import SwiftUI

/// The direction an arrow key or vi key (h/j/k/l) moves in. The screens
/// share it so they agree on which keys move, and each screen defines what
/// a move does there.
nonisolated enum MoveDirection: Equatable {
    case left, right, up, down

    /// Make the direction a key moves in, or nil for any other key. The
    /// letters are lowercased so they still work with Caps Lock on.
    init?(key: KeyEquivalent, characters: String) {
        switch key {
        case .leftArrow: self = .left
        case .rightArrow: self = .right
        case .upArrow: self = .up
        case .downArrow: self = .down
        default:
            switch characters.lowercased() {
            case "h": self = .left
            case "l": self = .right
            case "k": self = .up
            case "j": self = .down
            default: return nil
            }
        }
    }

    /// Make the direction a key press moves in, or nil for any other key.
    init?(_ press: KeyPress) {
        self.init(key: press.key, characters: press.characters)
    }

    /// How far this direction moves when stepping through photos in order,
    /// one at a time: back for left and up, forward for right and down.
    var linearStep: Int {
        switch self {
        case .left, .up: -1
        case .right, .down: 1
        }
    }
}
