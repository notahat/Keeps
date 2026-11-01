import SwiftUI

/// A print with no image: a card of a given shape in the border colour, with
/// a grey patch where the image would go. Drawn while a thumbnail loads, and
/// for the deep layers of a pile, which are mostly hidden and not worth a
/// thumbnail load. Laid out like ThumbnailImage, so the two line up.
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
