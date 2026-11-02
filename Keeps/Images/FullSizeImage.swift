import AppKit
import SwiftUI

/// One photo's full-size image, fitted to the space, with its neighbours
/// preloaded: the shown photo loads at high priority, and the 4 photos after
/// it and the 2 before it at low priority. Shows the photo's thumbnail while
/// the full image loads, or a spinner when there's no thumbnail either.
///
/// Draws and loads only. The caller handles keys and focus, draws anything
/// over the image, and changes `index` to move through `items`. Knows
/// nothing about groups or keepers.
struct FullSizeImage: View {
    let items: [PhotoItem]
    let index: Int

    /// The shown photo's full-size image, which redraws this view when it
    /// loads.
    @State private var fullImage: WatchedImage?

    /// The shown photo's thumbnail, which stands in until the full-size
    /// image loads.
    @State private var thumbnail: WatchedImage?

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
            if let shownImage = fullImage?.image ?? thumbnail?.image {
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
            loadPhotoAndNeighbours()
        }
        .onDisappear {
            deprioritizeHighPriorityLoad()
        }
        .onChange(of: index) {
            deprioritizeHighPriorityLoad()
            loadPhotoAndNeighbours()
        }
    }

    /// Watches the shown photo's images, loads its full-size image at high
    /// priority, and prefetches the photos around it.
    private func loadPhotoAndNeighbours() {
        highPriorityItem = item
        fullImage = ImagePipeline.shared.watchedImage(for: item, size: .full)
        thumbnail = ImagePipeline.shared.watchedImage(for: item, size: ThumbnailImage.imageSize)
        ImagePipeline.shared.requestImage(for: item, size: .full)
        for preloadIndex in preloadIndices() {
            ImagePipeline.shared.prefetchImage(for: items[preloadIndex], size: .full)
        }
    }

    /// Drops the in-flight high-priority load back to prefetch priority.
    private func deprioritizeHighPriorityLoad() {
        guard let highPriorityItem else { return }
        ImagePipeline.shared.deprioritizeImage(for: highPriorityItem, size: .full)
        self.highPriorityItem = nil
    }

    /// The indices to preload: up to 4 ahead and 2 behind the shown photo.
    private func preloadIndices() -> [Int] {
        (max(0, index - 2) ... min(items.count - 1, index + 4)).filter { $0 != index }
    }
}
