import SwiftUI

/// Some photos drawn as a messy pile of prints in a square, the first on top,
/// each tilted and nudged by its PileJitter. Only the top few prints show
/// their photos; the few beneath are blank paper, since they're mostly
/// hidden and each photo costs a thumbnail load, and deeper layers aren't
/// drawn at all. Draws only, with no label; the screens add their own.
struct PrintPile: View {
    let photos: [PhotoItem]

    /// The width and height of the square the pile fills.
    let length: CGFloat

    /// The photos' usual shape, for the blank paper.
    let aspectRatio: CGFloat

    /// How many prints, from the top, show their photos. Shared with the
    /// sort screen's collapsed groups, so every pile is drawn alike.
    static let photoLayerCount = 5

    /// How many prints are drawn in all, counting the blank ones.
    static let maximumLayerCount = 8

    private static let borderWidth: CGFloat = 6

    var body: some View {
        ZStack {
            ForEach(Array(photos.prefix(Self.maximumLayerCount).enumerated()).reversed(), id: \.element.id) { layer, photo in
                pilePrint(of: photo, layer: layer)
                    .placedInPile(PileJitter(stem: photo.stem))
            }
        }
        .frame(width: length, height: length)
    }

    /// One print on the pile, untilted: the photo for the top few layers,
    /// otherwise blank paper. Only the top print loads urgently; the others
    /// are mostly hidden, so they load in the background.
    @ViewBuilder private func pilePrint(of photo: PhotoItem, layer: Int) -> some View {
        if layer < Self.photoLayerCount {
            ThumbnailImage(
                item: photo,
                borderWidth: Self.borderWidth,
                loadsInBackground: layer > 0,
                placeholder: .paper(aspectRatio: aspectRatio),
                frameSize: CGSize(width: length, height: length)
            )
        } else {
            BlankPrint(aspectRatio: aspectRatio, borderWidth: Self.borderWidth)
                .frame(width: length, height: length)
        }
    }
}

extension View {
    /// Places a print in a messy pile: shrunk a little to leave room for the
    /// tilt, shadowed, and tilted and nudged by its jitter.
    func placedInPile(_ jitter: PileJitter) -> some View {
        scaleEffect(0.8)
            .shadow(color: .black.opacity(0.5), radius: 3)
            .rotationEffect(.degrees(jitter.rotationDegrees))
            .offset(x: jitter.horizontalOffset, y: jitter.verticalOffset)
    }
}

/// The label under a PrintPile, such as "5 set aside": on a plain material,
/// or in white on a colour when given one, to make a pile stand out.
struct PileLabel: View {
    let text: String
    var color: Color?

    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(color == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(.white))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
            .shadow(color: .black.opacity(0.4), radius: 2)
    }

    /// The capsule's fill: the colour, or the plain material without one.
    private var background: AnyShapeStyle {
        color.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.regularMaterial)
    }
}
