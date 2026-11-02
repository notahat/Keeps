import SwiftUI

extension View {
    /// Makes this view a screen's keyboard target: it takes focus when it
    /// appears, shows no focus ring, and passes key presses to
    /// `handleKeyPress`, which returns whether it handled the key. Keys it
    /// doesn't handle carry on as if it weren't there.
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
