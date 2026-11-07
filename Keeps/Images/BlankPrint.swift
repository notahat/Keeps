import SwiftUI

/// A print with no image: a white card of a given shape, with a grey patch
/// where the image would go. It stands in while a thumbnail loads, and for
/// the deep layers of a pile, which are mostly hidden and not worth a
/// thumbnail load. It's laid out like FramedPhoto, so the two line up.
struct BlankPrint: View {
    /// The card's width over its height.
    let aspectRatio: CGFloat

    /// The width, in points, of the white card round the grey patch.
    var borderWidth: CGFloat = 0

    var body: some View {
        Color(white: 0.5)
            .padding(borderWidth)
            .background(borderWidth > 0 ? .white : .clear)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .padding(FramedPhoto.imageInset)
    }
}

/// The width and height, in points, of the space every preview fits its
/// print into: a framed photo's standard frame.
private let previewSize = CGFloat(FramedPhoto.standardFrameLength)

#Preview("Landscape, white border") {
    BlankPrint(aspectRatio: FramedPhoto.typicalAspectRatio, borderWidth: 6)
        .frame(width: previewSize, height: previewSize)
        .padding()
        .background(.black)
}

#Preview("Portrait, no border") {
    BlankPrint(aspectRatio: 1 / FramedPhoto.typicalAspectRatio)
        .frame(width: previewSize, height: previewSize)
        .padding()
        .background(.black)
}
