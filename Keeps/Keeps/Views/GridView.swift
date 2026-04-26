import SwiftUI

/// A scrollable grid of photo thumbnails that loads lazily as cells come into view.
struct GridView: View {
    let items: [PhotoItem]

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 2)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(items) { item in
                    ThumbnailView(item: item)
                }
            }
            .padding(2)
        }
    }
}
