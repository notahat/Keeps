import SwiftUI

/// A print with no image: a card of a given shape in the border colour, with
/// a grey patch where the image would go. It stands in while a thumbnail
/// loads, and for the deep layers of a pile, which are mostly hidden and not
/// worth a thumbnail load. It's laid out like ThumbnailImage, so the two
/// line up.
struct BlankPrint: View {
    /// The card's width over its height.
    let aspectRatio: CGFloat

    var borderWidth: CGFloat = 0
    var borderColor: Color = .white

    var body: some View {
        Color(white: 0.5)
            .padding(borderWidth)
            .background(borderWidth > 0 ? borderColor : .clear)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .padding(ThumbnailImage.imageInset)
    }
}

/// The space every preview fits its print into, the size thumbnails are
/// shown at.
private let previewSize = CGFloat(ThumbnailImage.displaySize)

#Preview("Landscape, white border") {
    BlankPrint(aspectRatio: ThumbnailImage.typicalAspectRatio, borderWidth: 6)
        .frame(width: previewSize, height: previewSize)
        .padding()
        .background(.black)
}

#Preview("Portrait, no border") {
    BlankPrint(aspectRatio: 1 / ThumbnailImage.typicalAspectRatio)
        .frame(width: previewSize, height: previewSize)
        .padding()
        .background(.black)
}
