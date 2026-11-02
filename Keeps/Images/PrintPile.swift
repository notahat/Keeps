import SwiftUI

/// Some photos drawn as a messy pile of prints in a square, the first on top,
/// each tilted and nudged by its PileJitter. Only the top few prints show
/// their photos; the few beneath are blank paper, since they're mostly
/// hidden and each photo costs a thumbnail load, and deeper layers aren't
/// drawn at all. Draws only, with no label or badge; callers add their own.
struct PrintPile: View {
    let photos: [PhotoItem]

    /// The width and height of the square the pile fills.
    let length: CGFloat

    /// The photos' usual shape, for the blank paper. When nil, the top
    /// photo's shape is used once it has loaded, which suits a group, whose
    /// photos are nearly always the same shape.
    var aspectRatio: CGFloat?

    /// A white border so each photo reads as a print on paper.
    var borderWidth: CGFloat = 6

    /// How many prints, from the top, show their photos.
    static let photoLayerCount = 5

    /// How many prints are drawn in all, counting the blank ones.
    static let maximumLayerCount = 20

    /// The top photo's shape, once loaded (see aspectRatio).
    @State private var topAspectRatio: CGFloat?

    var body: some View {
        ZStack {
            ForEach(Array(photos.prefix(Self.maximumLayerCount).enumerated()).reversed(), id: \.element.id) { layer, photo in
                pilePrint(of: photo, layer: layer)
                    .placedInPile(PileJitter(stem: photo.stem))
            }
        }
        .frame(width: length, height: length)
    }

    /// The shape for blank paper: the one given, or the top photo's.
    private var paperAspectRatio: CGFloat? {
        aspectRatio ?? topAspectRatio
    }

    /// One print on the pile, untilted: the photo for the top few layers,
    /// otherwise blank paper, or nothing until the paper's shape is known.
    /// Only the top print loads urgently; the others are mostly hidden, so
    /// they load in the background.
    @ViewBuilder private func pilePrint(of photo: PhotoItem, layer: Int) -> some View {
        if layer < Self.photoLayerCount {
            ThumbnailImage(
                item: photo,
                borderWidth: borderWidth,
                loadsInBackground: layer > 0,
                placeholder: placeholder(isTopLayer: layer == 0),
                frameSize: CGSize(width: length, height: length),
                onAspectRatioKnown: layer == 0 ? { topAspectRatio = $0 } : nil
            )
        } else if let paperAspectRatio {
            BlankPrint(aspectRatio: paperAspectRatio, borderWidth: borderWidth)
                .frame(width: length, height: length)
        }
    }

    /// What a print shows while loading: blank paper once its shape is
    /// known, otherwise the usual square for the top print and nothing for
    /// the ones beneath.
    private func placeholder(isTopLayer: Bool) -> ThumbnailImage.Placeholder {
        if let paperAspectRatio {
            return .paper(aspectRatio: paperAspectRatio)
        }
        return isTopLayer ? .square : .none
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

#Preview("Small pile, all photos") {
    PrintPile(photos: PreviewPhotos.makeItems(count: 3), length: 260)
        .padding()
        .background(.black)
}

#Preview("Large pile, blank prints beneath") {
    PrintPile(photos: PreviewPhotos.makeItems(count: 12), length: 260, aspectRatio: 1.5)
        .padding()
        .background(.black)
}

#Preview("Plain pile label") {
    PileLabel(text: "12 to go")
        .padding()
        .background(.black)
}

#Preview("Coloured pile label") {
    PileLabel(text: "5 keepers", color: .green)
        .padding()
        .background(.black)
}
