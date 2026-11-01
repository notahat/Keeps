import SwiftUI

/// One cell on the sort screen: the thumbnail plus the selection highlight,
/// the boundary bars on either side, and, for a collapsed group, a
/// stacked-cards look with a photo count. Bars are drawn centred in the gap
/// next to the cell, so a boundary at a row wrap shows at both the end of one
/// row and the start of the next.
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

    @Environment(\.controlActiveState) private var controlActiveState

    var body: some View {
        content
            .frame(width: PhotoGridMetrics.cellSize, height: PhotoGridMetrics.cellSize)
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

    /// The thumbnail, or for a collapsed group a stack with a count badge.
    @ViewBuilder private var content: some View {
        if let pile {
            CollapsedStack(pile: pile)
        } else {
            ThumbnailImage(item: item)
        }
    }
}

/// A collapsed group drawn as a messy pile of its photos in pile order (see
/// Pile), each tilted and nudged a little (see PileJitter), with the photo
/// count in the corner. Using the real photos keeps every layer the right
/// shape. Only the first few are drawn, since deeper layers can't be seen
/// and each one costs a thumbnail load.
private struct CollapsedStack: View {
    let pile: Pile

    private var photos: [PhotoItem] {
        pile.photos
    }

    private static let maximumLayerCount = 8
    private static let scale: CGFloat = 0.8

    /// The top photo's shape, once loaded. Photos in a group are nearly
    /// always the same shape, so the prints beneath borrow it for their
    /// blank paper until their own images arrive.
    @State private var topAspectRatio: CGFloat?

    var body: some View {
        ZStack {
            ForEach(Array(photos.prefix(Self.maximumLayerCount).enumerated()).reversed(), id: \.element.id) { layer, photo in
                let jitter = PileJitter(stem: photo.stem)
                let isTopLayer = layer == 0
                // A white border so each photo reads as a print on paper.
                // Only the top print is loaded urgently; the ones beneath
                // are mostly hidden, so they load in the background, shown
                // meanwhile as blank paper in the top photo's shape.
                ThumbnailImage(
                    item: photo,
                    borderWidth: 7,
                    loadsInBackground: !isTopLayer,
                    placeholder: placeholder(isTopLayer: isTopLayer),
                    onAspectRatioKnown: isTopLayer ? { topAspectRatio = $0 } : nil
                )
                .scaleEffect(Self.scale)
                .shadow(color: .black.opacity(0.5), radius: 3)
                .rotationEffect(.degrees(jitter.rotationDegrees))
                .offset(x: jitter.horizontalOffset, y: jitter.verticalOffset)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            PileBadge(photoCount: photos.count)
                .padding(10)
        }
    }

    /// What a print shows while loading: the usual square for the top one,
    /// and blank paper in the top photo's shape for the ones beneath, or
    /// nothing until that shape is known.
    private func placeholder(isTopLayer: Bool) -> ThumbnailImage.Placeholder {
        if isTopLayer {
            return .square
        }
        return topAspectRatio.map { .paper(aspectRatio: $0) } ?? .none
    }
}

/// The badge in a pile's corner: how many photos are in it.
private struct PileBadge: View {
    let photoCount: Int

    var body: some View {
        Text("\(photoCount)")
            .font(.callout.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            // Solid colour rather than white, so it stands out from both
            // the dark window and the white print borders.
            .background(Color.accentColor, in: Capsule())
            .shadow(color: .black.opacity(0.6), radius: 2)
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
