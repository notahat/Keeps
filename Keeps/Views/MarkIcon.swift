import SwiftUI

/// Renders the canonical icon for a mark value: checkmark for pick, X for
/// reject, minus for unmark (nil).
@ViewBuilder func markIcon(for mark: PassStore.Mark?) -> some View {
    switch mark {
    case .pick:
        Image(systemName: "checkmark.circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .green)
    case .reject:
        Image(systemName: "x.circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .red)
    case nil:
        Image(systemName: "minus.circle")
            .foregroundStyle(.secondary)
    }
}
