import AppKit
import SwiftUI

/// A fixed-size square cell that loads and displays a photo thumbnail.
/// Shows a neutral placeholder while loading. Uses .task(id:) so the load
/// is automatically cancelled if the cell scrolls out of view.
struct ThumbnailView: View {
    let item: PhotoItem
    var isSelected: Bool = false
    var mark: FolderLibrary.Mark? = nil

    @Environment(\.controlActiveState) private var controlActiveState

    // Request at 2x the display size for Retina screens.
    private static let displaySize: Int = 260
    private static let pixelSize: Int = displaySize * 2

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(3)
                    .overlay {
                        if isSelected && controlActiveState == .key {
                            Rectangle().stroke(Color.accentColor, lineWidth: 3)
                        }
                    }
                    .overlay(alignment: .bottomLeading) {
                        if let mark {
                            MarkBadge(mark: mark).padding(6)
                        }
                    }
            } else {
                Color(nsColor: .quaternaryLabelColor)
            }
        }
        .frame(width: CGFloat(Self.displaySize), height: CGFloat(Self.displaySize))
        .task(id: item.id) {
            image = await ImageLoader.shared.thumbnail(for: item, maxPixelSize: Self.pixelSize)
        }
    }
}

/// A small badge showing whether a photo has been picked or rejected.
private struct MarkBadge: View {
    let mark: FolderLibrary.Mark

    var body: some View {
        Image(systemName: mark == .pick ? "checkmark.circle.fill" : "x.circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, mark == .pick ? Color.green : Color.red)
            .font(.system(size: 22))
            .shadow(radius: 2)
    }
}
