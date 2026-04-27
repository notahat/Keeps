import AppKit
import SwiftUI

/// Full-window view of a single photo. Esc or G returns to the grid. Left/right
/// arrow keys and h/l navigate between photos; j/k also navigate linearly.
/// The current image loads at high priority; the surrounding preload window loads
/// at low priority and is left in the queue when navigating away.
struct SingleImageView: View {
    var library: FolderLibrary

    @State private var image: NSImage?

    /// The item currently being loaded at high priority, tracked so it can be
    /// deprioritised when the user navigates away before it finishes.
    @State private var highPriorityItem: PhotoItem?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay(alignment: .bottomLeading) {
                        if let item = selectedItem, let mark = library.marks[item.id] {
                            MarkBadge(mark: mark, fontSize: 40).padding(12)
                        }
                    }
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
        .background {
            KeyAwareView { event in handleKeyEvent(event) }
        }
        .onAppear {
            loadWindow()
        }
        .onDisappear {
            deprioritizeCurrent()
        }
        .onChange(of: library.selectedIndex) {
            image = nil
            deprioritizeCurrent()
            loadWindow()
        }
        .onReceive(NotificationCenter.default.publisher(for: ImageLoader.fullImageLoadedNotification)) { notification in
            guard let item = selectedItem,
                  (notification.userInfo?[ImageLoader.fullImageItemIDKey] as? UUID) == item.id
            else { return }
            image = ImageLoader.shared.cachedFullImage(for: item)
        }
    }

    private var selectedItem: PhotoItem? {
        guard let index = library.selectedIndex, index < library.filteredItems.count else { return nil }
        return library.filteredItems[index]
    }

    private func loadWindow() {
        guard let index = library.selectedIndex else { image = nil; return }
        let items = library.filteredItems
        let item = items[index]
        highPriorityItem = item
        image = ImageLoader.shared.cachedFullImage(for: item)
        ImageLoader.shared.requestFullImage(for: item)
        for idx in preloadIndices(around: index, in: items) {
            ImageLoader.shared.prefetchFullImage(for: items[idx])
        }
    }

    private func deprioritizeCurrent() {
        if let item = highPriorityItem {
            ImageLoader.shared.deprioritizeFullImage(for: item)
            highPriorityItem = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        if event.keyCode == .escape || event.charactersIgnoringModifiers == "g" {
            library.viewMode = .grid
            return true
        }
        if let mark = markForKey(event.charactersIgnoringModifiers), let index = library.selectedIndex {
            library.setMark(mark, for: library.filteredItems[index])
            let items = library.filteredItems
            library.selectedIndex = items.isEmpty ? nil : min(items.count - 1, index + 1)
            return true
        }
        guard let step = navigationStep(for: event) else { return false }
        let count = library.filteredItems.count
        guard count > 0, let current = library.selectedIndex else { return false }
        library.selectedIndex = max(0, min(count - 1, current + step))
        return true
    }

    /// Returns the mark (or nil to unmark) for f/s/d keys, or nil if not a mark key.
    private func markForKey(_ key: String?) -> FolderLibrary.Mark?? {
        switch key {
        case "f": .some(.pick)
        case "s": .some(.reject)
        case "d": .some(nil)
        default: nil
        }
    }

    /// Returns 4 indices ahead and 2 behind, excluding the current index.
    private func preloadIndices(around index: Int, in items: [PhotoItem]) -> [Int] {
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
