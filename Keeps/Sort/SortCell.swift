import SwiftUI

/// One cell on the sort screen: the photo plus the selection highlight,
/// the boundary bars on either side, and, for a collapsed group, a pile of
/// prints with a photo count. Bars are drawn centred in the gap next to the
/// cell, so a boundary at a row wrap shows at both the end of one row and
/// the start of the next.
struct SortCell: View {
    let item: PhotoItem
    var isSelected: Bool = false
    var leadingBoundary: BoundaryStyle?
    var trailingBoundary: BoundaryStyle?

    /// The pile to draw when this cell is a collapsed group; nil for a
    /// single photo.
    var pile: Pile?

    /// How a boundary bar is drawn: placed, or previewed under the pointer.
    enum BoundaryStyle {
        case placed, preview
    }

    var body: some View {
        content
            .frame(width: PhotoGridMetrics.cellSize, height: PhotoGridMetrics.cellSize)
            .selectionHighlight(isSelected: isSelected)
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

    /// The photo, or for a collapsed group a pile with its photo count.
    @ViewBuilder private var content: some View {
        if let pile {
            CollapsedGroup(pile: pile)
        } else {
            FramedPhoto(item: item)
        }
    }
}

/// A collapsed group drawn as a PrintPile of its photos in pile order (see
/// Pile), with the photo count in the corner.
private struct CollapsedGroup: View {
    let pile: Pile

    var body: some View {
        PrintPile(photos: pile.photos, length: PhotoGridMetrics.cellSize, borderWidth: PrintPile.standardFrameBorderWidth)
            .overlay(alignment: .bottomTrailing) {
                // Solid colour rather than white, so it stands out from both
                // the dark window and the white print borders.
                PileLabel(text: "\(pile.photos.count)", color: .accentColor)
                    .padding(10)
            }
    }
}

/// A vertical bar marking a group boundary in the gap beside a cell.
private struct BoundaryBar: View {
    let style: SortCell.BoundaryStyle

    static let width: CGFloat = 4

    var body: some View {
        Capsule()
            .fill(style == .placed ? Color.accentColor : Color.accentColor.opacity(0.35))
            .frame(width: Self.width)
            .allowsHitTesting(false)
    }
}

#Preview("Single photo") {
    SortCell(item: PreviewPhotos.landscape)
        .padding()
        .background(.black)
}

#Preview("Selected photo") {
    SortCell(item: PreviewPhotos.landscape, isSelected: true)
        .padding()
        .background(.black)
}

#Preview("Boundaries placed on both sides") {
    SortCell(item: PreviewPhotos.portrait, leadingBoundary: .placed, trailingBoundary: .placed)
        .padding()
        .background(.black)
}

#Preview("Boundary previewed under the pointer") {
    SortCell(item: PreviewPhotos.portrait, trailingBoundary: .preview)
        .padding()
        .background(.black)
}

#Preview("Collapsed group") {
    let photos = PreviewPhotos.makeItems(count: 7)
    SortCell(item: photos[0], pile: Pile(group: 0 ..< 7, items: photos, keepers: []))
        .padding()
        .background(.black)
}
