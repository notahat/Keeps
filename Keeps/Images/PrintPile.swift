import SwiftUI

/// Draws some photos as a messy pile of prints in a square, the first on
/// top, each tilted and nudged by its PileJitter.
///
/// Only the top few prints (photoLayerCount) show their photos. The prints
/// beneath are mostly hidden, so they're drawn as blank prints rather than
/// costing a thumbnail load each, and prints beyond maximumLayerCount
/// aren't drawn at all.
///
/// It draws no label or badge; callers add their own.
struct PrintPile: View {
    /// The photos in the pile, the top one first.
    let photos: [PhotoItem]

    /// The width and height, in points, of the square the pile fills.
    let length: CGFloat

    /// The photos' usual shape, for the blank prints. When nil, the top
    /// photo's shape is used once it has loaded, which suits a group, whose
    /// photos are nearly always the same shape.
    var aspectRatio: CGFloat?

    /// The width, in points, of a white border so each photo reads as a
    /// print on paper.
    var borderWidth: CGFloat = 6

    /// The border width, in points, for a pile as large as the standard
    /// frame, as on the sort and done screens: a little wider than the
    /// default, to suit the larger prints.
    static let standardFrameBorderWidth: CGFloat = 7

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

    /// The shape for blank prints: the one given, or the top photo's.
    private var blankPrintAspectRatio: CGFloat? {
        aspectRatio ?? topAspectRatio
    }

    /// Draw one print on the pile, untilted: the photo for the top few
    /// layers, otherwise a blank print, or nothing until the print's shape
    /// is known. `layer` counts down from the top print, which is 0.
    /// Only the top print loads urgently; the others are mostly hidden, so
    /// they load in the background.
    @ViewBuilder private func pilePrint(of photo: PhotoItem, layer: Int) -> some View {
        if layer < Self.photoLayerCount {
            FramedPhoto(
                photo: photo,
                borderWidth: borderWidth,
                shouldLoadInBackground: layer > 0,
                placeholder: placeholder(isTopLayer: layer == 0),
                frameSize: CGSize(width: length, height: length),
                onAspectRatioKnown: layer == 0 ? { topAspectRatio = $0 } : nil
            )
        } else if let blankPrintAspectRatio {
            BlankPrint(aspectRatio: blankPrintAspectRatio, borderWidth: borderWidth)
                .frame(width: length, height: length)
        }
    }

    /// Choose what a print shows while loading: a blank print once its shape
    /// is known, otherwise the usual square for the top print and nothing
    /// for the ones beneath.
    private func placeholder(isTopLayer: Bool) -> FramedPhoto.Placeholder {
        if let blankPrintAspectRatio {
            return .blankPrint(aspectRatio: blankPrintAspectRatio)
        }
        return isTopLayer ? .square : .none
    }
}

private extension View {
    /// Place a print in a messy pile: shrunk a little to leave room for the
    /// tilt, shadowed, and tilted and nudged by its jitter.
    func placedInPile(_ jitter: PileJitter) -> some View {
        scaleEffect(0.8)
            .shadow(color: .black.opacity(0.5), radius: 3)
            .rotationEffect(.degrees(jitter.rotationDegrees))
            .offset(x: jitter.horizontalOffset, y: jitter.verticalOffset)
    }
}

#Preview("Small pile, all photos") {
    PrintPile(photos: PreviewPhotos.makePhotos(count: 3), length: 260)
        .padding()
        .background(.black)
}

#Preview("Large pile, blank prints beneath") {
    PrintPile(photos: PreviewPhotos.makePhotos(count: 12), length: 260, aspectRatio: FramedPhoto.typicalAspectRatio)
        .padding()
        .background(.black)
}
