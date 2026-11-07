import SwiftUI

/// The pile in a done group's corner on the pick screen: the photos that
/// weren't kept, as a PrintPile with a count. Draws only: PickScreen
/// supplies the photos and places the pile.
struct SetAsidePile: View {
    let photos: [PhotoItem]

    /// The width and height of the square the pile fills.
    let length: CGFloat

    /// The group's common photo shape (see PrintPile).
    let aspectRatio: CGFloat

    var body: some View {
        PrintPile(photos: photos, length: length, aspectRatio: aspectRatio)
            .overlay(alignment: .bottom) {
                PileLabel(text: "\(photos.count) set aside")
            }
    }
}

#Preview("Set-aside pile") {
    SetAsidePile(photos: PreviewPhotos.makePhotos(count: 4), length: 200, aspectRatio: FramedPhoto.typicalAspectRatio)
        .padding()
        .background(.black)
}
