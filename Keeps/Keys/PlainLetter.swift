import SwiftUI

/// Return whether a key is the given lowercase letter with none of ⌘, ⌃, or
/// ⌥ held, so a screen's letter keys don't catch menu shortcuts such as ⌘C.
/// Shift and Caps Lock are allowed.
nonisolated func isPlainLetter(_ letter: String, characters: String, modifiers: EventModifiers) -> Bool {
    modifiers.isDisjoint(with: [.command, .control, .option])
        && characters.lowercased() == letter
}

extension KeyPress {
    /// Return whether this press is the given lowercase letter with none of
    /// ⌘, ⌃, or ⌥ held.
    func isPlain(letter: String) -> Bool {
        isPlainLetter(letter, characters: characters, modifiers: modifiers)
    }
}
