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
/// count in the corner. Using the real photos keeps the visible layers the
/// right shape. Drawn like a PrintPile: only the top few prints show their
/// photos, the few beneath are blank paper, and deeper layers aren't drawn,
/// since they can't be seen and each photo costs a thumbnail load.
private struct CollapsedStack: View {
    let pile: Pile

    private var photos: [PhotoItem] {
        pile.photos
    }

    /// A white border so each photo reads as a print on paper.
    private static let borderWidth: CGFloat = 7

    /// The top photo's shape, once loaded. Photos in a group are nearly
    /// always the same shape, so the prints beneath borrow it for their
    /// blank paper.
    @State private var topAspectRatio: CGFloat?

    var body: some View {
        ZStack {
            ForEach(Array(photos.prefix(PrintPile.maximumLayerCount).enumerated()).reversed(), id: \.element.id) { layer, photo in
                pilePrint(of: photo, layer: layer)
                    .placedInPile(PileJitter(stem: photo.stem))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            PileBadge(photoCount: photos.count)
                .padding(10)
        }
    }

    /// One print on the pile, untilted: the photo for the top few layers,
    /// otherwise blank paper in the top photo's shape, or nothing until that
    /// shape is known. Only the top print loads urgently; the others are
    /// mostly hidden, so they load in the background.
    @ViewBuilder private func pilePrint(of photo: PhotoItem, layer: Int) -> some View {
        if layer < PrintPile.photoLayerCount {
            ThumbnailImage(
                item: photo,
                borderWidth: Self.borderWidth,
                loadsInBackground: layer > 0,
                placeholder: placeholder(isTopLayer: layer == 0),
                onAspectRatioKnown: layer == 0 ? { topAspectRatio = $0 } : nil
            )
        } else if let topAspectRatio {
            BlankPrint(aspectRatio: topAspectRatio, borderWidth: Self.borderWidth)
                .frame(width: PhotoGridMetrics.cellSize, height: PhotoGridMetrics.cellSize)
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
