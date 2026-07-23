import AppKit
import SwiftUI

/// Full-window view of the photo at selectedIndex. Owns full-size image
/// loading — the current photo at high priority, a preload window (4 ahead,
/// 2 behind) at low priority — the loading placeholder, keyboard focus, and
/// the interpretation of linear navigation keys (arrows and h/j/k/l) into
/// ±1 NavigationProposals. All policy and chrome belong to the caller via
/// onNavigate/onKeyDown and the overlay closure. Knows nothing about marks,
/// filters, or any other workflow concept.
struct PhotoDetailSurface<Overlay: View>: View {
    var items: [PhotoItem]
    var selectedIndex: Int?
    var onNavigate: (NavigationProposal) -> Void

    /// Receives every key press that isn't a linear navigation key.
    /// Returns true when the key was handled.
    var onKeyDown: (NSEvent) -> Bool

    /// Chrome layered over the full surface for the current photo.
    @ViewBuilder var overlay: (_ item: PhotoItem) -> Overlay

    @State private var image: NSImage?

    /// The item currently being loaded at high priority, tracked so it can be
    /// deprioritised when the user navigates away before it finishes.
    @State private var highPriorityItem: PhotoItem?
    @State private var keyView: KeyAwareView.ResponderView?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
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
        .onTapGesture {
            keyView?.window?.makeFirstResponder(keyView)
        }
        .background {
            KeyAwareView(onKeyDown: { event in handleKeyEvent(event) }, onViewReady: { keyView = $0 })
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

    /// Turns linear navigation keys into ±1 proposals; forwards everything
    /// else to onKeyDown.
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard let step = navigationStep(for: event),
              !items.isEmpty,
              let current = selectedIndex
        else { return onKeyDown(event) }
        onNavigate(NavigationProposal(
            targetIndex: max(0, min(items.count - 1, current + step)),
            extendsRange: event.modifierFlags.contains(.shift)
        ))
        return true
    }

    /// Returns 4 indices ahead and 2 behind, excluding the current index.
    private func preloadIndices(around index: Int) -> [Int] {
        (max(0, index - 2) ... min(items.count - 1, index + 4)).filter { $0 != index }
    }

    private func navigationStep(for event: NSEvent) -> Int? {
        switch event.keyCode {
        case .leftArrow, .upArrow: return -1
        case .rightArrow, .downArrow: return 1
        default: break
        }
        switch event.charactersIgnoringModifiers {
        case "h", "k": return -1
        case "l", "j": return 1
        default: return nil
        }
    }
}
