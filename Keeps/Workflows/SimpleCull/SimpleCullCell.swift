import SwiftUI

/// One grid cell in the simple culling workflow: the kit thumbnail plus the
/// workflow's chrome — selection highlight, range highlight, and mark badge.
struct SimpleCullCell: View {
    let item: PhotoItem
    var isSelected: Bool = false
    var isInSelectionRange: Bool = false
    var mark: MarkStore.Mark?

    @Environment(\.controlActiveState) private var controlActiveState

    var body: some View {
        ThumbnailImage(item: item)
            .overlay {
                if isInSelectionRange {
                    Rectangle().fill(Color.accentColor.opacity(0.2))
                }
            }
            .overlay {
                if isSelected, controlActiveState == .key {
                    Rectangle().stroke(Color.accentColor, lineWidth: 3)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if let mark {
                    MarkBadge(mark: mark).padding(6)
                }
            }
    }
}

/// A small badge showing whether a photo has been picked or rejected.
struct MarkBadge: View {
    let mark: MarkStore.Mark
    var fontSize: CGFloat = 22

    var body: some View {
        markIcon(for: mark)
            .font(.system(size: fontSize))
            .shadow(radius: 2)
    }
}
