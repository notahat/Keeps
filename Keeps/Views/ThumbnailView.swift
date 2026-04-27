import AppKit
import SwiftUI

/// A fixed-size square cell that loads and displays a photo thumbnail.
/// Shows a neutral placeholder while loading. Requests high-priority loading
/// on appear and deprioritises on disappear so that currently-visible cells
/// are always decoded first.
struct ThumbnailView: View {
    let item: PhotoItem
    var isSelected: Bool = false
    var mark: FolderLibrary.Mark?

    @Environment(\.controlActiveState) private var controlActiveState

    // Request at 2x the display size for Retina screens.
    private static let displaySize: Int = 260
    static let pixelSize: Int = displaySize * 2
    static let imageSize: ImageSize = .thumbnail(maxPixelSize: pixelSize)

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(3)
                    .overlay {
                        if isSelected, controlActiveState == .key {
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
        .onAppear {
            if let cached = ImageLoader.shared.cachedImage(for: item, size: Self.imageSize) {
                image = cached
            } else {
                ImageLoader.shared.requestImage(for: item, size: Self.imageSize)
            }
        }
        .onDisappear {
            ImageLoader.shared.deprioritizeImage(for: item, size: Self.imageSize)
        }
        .onReceive(NotificationCenter.default.publisher(for: ImageLoader.imageLoadedNotification)) { notification in
            guard (notification.userInfo?[ImageLoader.imageLoadedItemIDKey] as? UUID) == item.id else { return }
            image = ImageLoader.shared.cachedImage(for: item, size: Self.imageSize)
        }
    }
}

/// A small badge showing whether a photo has been picked or rejected.
struct MarkBadge: View {
    let mark: FolderLibrary.Mark
    var fontSize: CGFloat = 22

    var body: some View {
        markIcon(for: mark)
            .font(.system(size: fontSize))
            .shadow(radius: 2)
    }
}
