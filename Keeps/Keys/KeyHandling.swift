import SwiftUI

/// Key handling the screens share, so each screen's main view takes the
/// keyboard the same way. The sort and done screens, and the tiles of the
/// pick and keepers screens, each put `handlesKeys` on the view that should
/// receive key presses, and own the focus state it binds to, so they can
/// take focus back when something else, such as the full-size view, has
/// had it.
///
/// The modifier only routes key presses. It doesn't decide what any key
/// does, and doesn't filter out keys with ⌘, ⌃, or ⌥ held; each screen does
/// both, using MoveDirection and isPlainLetter.
extension View {
    /// Make this view a screen's keyboard target: the view takes focus when
    /// it appears, shows no focus ring, and passes key presses to
    /// `handleKeyPress`, which returns whether it handled the key. Keys it
    /// doesn't handle carry on as if the view weren't there.
    func handlesKeys(hasKeyboardFocus: FocusState<Bool>.Binding, perform handleKeyPress: @escaping (KeyPress) -> Bool) -> some View {
        focusable()
            .focusEffectDisabled()
            .focused(hasKeyboardFocus)
            .onKeyPress { press in
                handleKeyPress(press) ? .handled : .ignored
            }
            .onAppear {
                hasKeyboardFocus.wrappedValue = true
            }
    }
}
