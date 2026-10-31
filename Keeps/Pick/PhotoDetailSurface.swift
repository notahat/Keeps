import AppKit
import SwiftUI

/// Full-window view of the photo at selectedIndex. Owns full-size image
/// loading — the current photo at high priority, a preload window (4 ahead,
/// 2 behind) at low priority — and what shows while it loads: the
/// thumbnail if there is one, otherwise a spinner. Display only:
/// keys, focus, and chrome belong to the caller, which changes
/// selectedIndex and supplies the overlay. Knows nothing about groups or
/// keepers.
struct PhotoDetailSurface<Overlay: View>: View {
    var items: [PhotoItem]
    var selectedIndex: Int?

    /// Chrome layered over the full surface for the current photo.
    @ViewBuilder var overlay: (_ item: PhotoItem) -> Overlay

    @State private var image: NSImage?

    /// The item currently being loaded at high priority, tracked so it can be
    /// deprioritised when the user navigates away before it finishes.
    @State private var highPriorityItem: PhotoItem?

    var body: some View {
        Group {
            // The sort screen's thumbnail stands in while the full image
            // loads, so there's a photo to see straight away.
            if let shownImage = image ?? selectedItem.flatMap(cachedThumbnail) {
                Image(nsImage: shownImage)
                    .resizable()
                    .scaledToFit()
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    if let item = selectedItem {
                        Text(item.stem)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if let item = selectedItem {
                overlay(item)
            }
        }
        .onAppear {
            loadWindow()
        }
        .onDisappear {
            deprioritizeCurrent()
        }
        .onChange(of: selectedIndex) {
            deprioritizeCurrent()
            loadWindow()
        }
        .onReceive(NotificationCenter.default.publisher(for: ImagePipeline.imageLoadedNotification)) { notification in
            guard let item = selectedItem,
                  (notification.userInfo?[ImagePipeline.imageLoadedItemIDKey] as? UUID) == item.id
            else { return }
            image = ImagePipeline.shared.cachedImage(for: item, size: .full)
        }
    }

    /// The photo's thumbnail, if it's already loaded.
    private func cachedThumbnail(for item: PhotoItem) -> NSImage? {
        ImagePipeline.shared.cachedImage(for: item, size: ThumbnailImage.imageSize)
    }

    private var selectedItem: PhotoItem? {
        guard let index = selectedIndex, index < items.count else { return nil }
        return items[index]
    }

    /// Loads the current photo at high priority and prefetches the photos
    /// around it.
    private func loadWindow() {
        guard let index = selectedIndex, items.indices.contains(index) else {
            image = nil
            return
        }
        let item = items[index]
        highPriorityItem = item
        image = ImagePipeline.shared.cachedImage(for: item, size: .full)
        ImagePipeline.shared.requestImage(for: item, size: .full)
        for preloadIndex in preloadIndices(around: index) {
            ImagePipeline.shared.prefetchImage(for: items[preloadIndex], size: .full)
        }
    }

    /// Drops the in-flight high-priority load back to prefetch priority.
    private func deprioritizeCurrent() {
        if let item = highPriorityItem {
            ImagePipeline.shared.deprioritizeImage(for: item, size: .full)
            highPriorityItem = nil
        }
    }

    /// Returns 4 indices ahead and 2 behind, excluding the current index.
    private func preloadIndices(around index: Int) -> [Int] {
        (max(0, index - 2) ... min(items.count - 1, index + 4)).filter { $0 != index }
    }
}
