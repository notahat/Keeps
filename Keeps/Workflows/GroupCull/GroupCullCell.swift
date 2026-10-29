import SwiftUI

/// One grid cell in the grouping workflow: the kit thumbnail plus the
/// workflow's chrome — selection highlight, the boundary bars on either side,
/// and, for a collapsed group, a stacked-cards look with a photo count. Bars
/// are drawn centred in the gap next to the cell, so a boundary at a row wrap
/// shows at both the end of one row and the start of the next.
struct GroupCullCell: View {
    let item: PhotoItem
    var isSelected: Bool = false
    var leadingBoundary: BoundaryStyle?
    var trailingBoundary: BoundaryStyle?

    /// The number of photos in the group, when this cell is a collapsed
    /// group; nil for a single photo.
    var collapsedCount: Int?

    /// How a boundary bar is drawn: placed, or previewed under the pointer.
    enum BoundaryStyle {
        case placed, preview
    }

    @Environment(\.controlActiveState) private var controlActiveState

    var body: some View {
        ThumbnailImage(item: item)
            .overlay {
                if isSelected, controlActiveState == .key {
                    Rectangle().stroke(Color.accentColor, lineWidth: 3)
                }
            }
            .overlay(alignment: .leading) {
                if let leadingBoundary {
                    BoundaryBar(style: leadingBoundary)
                        .offset(x: -PhotoGridMetrics.spacing / 2 - BoundaryBar.width / 2)
                }
            }
            .overlay(alignment: .trailing) {
                if let trailingBoundary {
                    BoundaryBar(style: trailingBoundary)
                        .offset(x: PhotoGridMetrics.spacing / 2 + BoundaryBar.width / 2)
                }
            }
    }
}

/// A vertical bar marking a group boundary in the gap beside a cell.
private struct BoundaryBar: View {
    let style: GroupCullCell.BoundaryStyle

    static let width: CGFloat = 4

    var body: some View {
        Capsule()
            .fill(style == .placed ? Color.accentColor : Color.accentColor.opacity(0.35))
            .frame(width: Self.width)
            .allowsHitTesting(false)
    }
}
