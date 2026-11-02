import AppKit
import SwiftUI

/// One photo's full-size image, fitted to the space, with its neighbours
/// preloaded: the shown photo loads at high priority, and a window of 4
/// ahead and 2 behind at low priority. Shows the photo's thumbnail while the
/// full image loads, or a spinner when there's no thumbnail either.
///
/// Draws and loads only: keys, focus, and chrome belong to the caller, which
/// changes `index` to move through `items`. Knows nothing about groups or
/// keepers.
struct FullSizeImage: View {
    let items: [PhotoItem]
    let index: Int

    @State private var image: NSImage?

    /// The item being loaded at high priority, tracked so it can be
    /// deprioritised when the user moves on before it finishes.
    @State private var highPriorityItem: PhotoItem?

    private var item: PhotoItem {
        items[index]
    }

    var body: some View {
        Group {
            // The sort screen's thumbnail stands in while the full image
            // loads, so there's a photo to see straight away.
            if let shownImage = image ?? cachedThumbnail {
                Image(nsImage: shownImage)
                    .resizable()
                    .scaledToFit()
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text(item.stem)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadWindow()
        }
        .onDisappear {
            deprioritizeCurrent()
        }
        .onChange(of: index) {
            deprioritizeCurrent()
            loadWindow()
        }
        .onImageLoaded(for: item) {
            image = ImagePipeline.shared.cachedImage(for: item, size: .full)
        }
    }

    /// The shown photo's thumbnail, if it's already loaded.
    private var cachedThumbnail: NSImage? {
        ImagePipeline.shared.cachedImage(for: item, size: ThumbnailImage.imageSize)
    }

    /// Loads the shown photo at high priority and prefetches the photos
    /// around it.
    private func loadWindow() {
        highPriorityItem = item
        image = ImagePipeline.shared.cachedImage(for: item, size: .full)
        ImagePipeline.shared.requestImage(for: item, size: .full)
        for preloadIndex in preloadIndices() {
            ImagePipeline.shared.prefetchImage(for: items[preloadIndex], size: .full)
        }
    }

    /// Drops the in-flight high-priority load back to prefetch priority.
    private func deprioritizeCurrent() {
        guard let highPriorityItem else { return }
        ImagePipeline.shared.deprioritizeImage(for: highPriorityItem, size: .full)
        self.highPriorityItem = nil
    }

    /// The indices to preload: up to 4 ahead and 2 behind the shown photo.
    private func preloadIndices() -> [Int] {
        (max(0, index - 2) ... min(items.count - 1, index + 4)).filter { $0 != index }
    }
}
