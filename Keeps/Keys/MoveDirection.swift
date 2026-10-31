import SwiftUI

/// The direction an arrow key or vi key (h/j/k/l) moves in. Shared by the
/// screens so they agree on which keys move; what a move does is left to
/// each screen.
nonisolated enum MoveDirection: Equatable {
    case left, right, up, down

    /// The direction a key moves in, or nil for any other key. The letters
    /// are lowercased so they still work with Caps Lock on.
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

    /// The direction a key press moves in, or nil for any other key.
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

/// Whether a key is the given lowercase letter with none of ⌘, ⌃, or ⌥ held,
/// so a screen's letter keys don't catch menu shortcuts such as ⌘C. Shift
/// and Caps Lock are allowed.
nonisolated func isPlainLetter(_ letter: String, characters: String, modifiers: EventModifiers) -> Bool {
    modifiers.isDisjoint(with: [.command, .control, .option])
        && characters.lowercased() == letter
}

extension KeyPress {
    /// Whether this press is the given lowercase letter with none of ⌘, ⌃,
    /// or ⌥ held.
    func isPlain(letter: String) -> Bool {
        isPlainLetter(letter, characters: characters, modifiers: modifiers)
    }
}
