import SwiftUI

/// A toolbar button for pick/reject/unmark actions. Shows a coloured SF Symbol
/// matching the thumbnail badges, with the keyboard shortcut key overlaid as a
/// small badge in the bottom-right corner.
struct MarkButton: View {
    enum MarkAction { case pick, reject, unmark }

    let markAction: MarkAction
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                icon
                Text(key)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(!isEnabled)
    }

    private var icon: some View {
        switch markAction {
        case .pick: markIcon(for: .pick)
        case .reject: markIcon(for: .reject)
        case .unmark: markIcon(for: nil)
        }
    }

    private var key: String {
        switch markAction {
        case .pick: "F"
        case .reject: "S"
        case .unmark: "D"
        }
    }
}
