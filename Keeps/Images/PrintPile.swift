import SwiftUI

/// Some photos drawn as a messy pile of prints in a square, the first on top,
/// each tilted and nudged by its PileJitter. Only the first few are drawn,
/// since deeper layers can't be seen and each one costs a thumbnail load.
/// Draws only, with no label; the screens add their own.
struct PrintPile: View {
    let photos: [PhotoItem]

    /// The width and height of the square the pile fills.
    let length: CGFloat

    /// The photos' usual shape, for the blank paper the lower prints show
    /// until their images arrive.
    let aspectRatio: CGFloat

    private static let maximumLayerCount = 8
    private static let printScale: CGFloat = 0.8

    var body: some View {
        ZStack {
            ForEach(Array(photos.prefix(Self.maximumLayerCount).enumerated()).reversed(), id: \.element.id) { layer, photo in
                pilePrint(of: photo, isTopLayer: layer == 0)
            }
        }
        .frame(width: length, height: length)
    }

    /// One photo as a print on the pile. Only the top print loads urgently;
    /// the ones beneath are mostly hidden, so they load in the background.
    private func pilePrint(of photo: PhotoItem, isTopLayer: Bool) -> some View {
        let jitter = PileJitter(stem: photo.stem)
        return ThumbnailImage(
            item: photo,
            borderWidth: 6,
            loadsInBackground: !isTopLayer,
            placeholder: .paper(aspectRatio: aspectRatio),
            frameSize: CGSize(width: length, height: length)
        )
        .scaleEffect(Self.printScale)
        .shadow(color: .black.opacity(0.5), radius: 3)
        .rotationEffect(.degrees(jitter.rotationDegrees))
        .offset(x: jitter.horizontalOffset, y: jitter.verticalOffset)
    }
}

/// The label under a PrintPile, such as "5 set aside".
struct PileLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.4), radius: 2)
    }
}
