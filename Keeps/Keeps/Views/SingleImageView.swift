import AppKit
import os
import SwiftUI

/// Full-window view of a single photo. Esc returns to the grid. Left/right arrow
/// keys and h/l navigate between photos; j/k also navigate linearly.
struct SingleImageView: View {
    var library: FolderLibrary

    @State private var image: NSImage?

    private let signposter = OSSignposter(subsystem: "com.notahat.Keeps", category: "Navigation")

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Color(nsColor: .quaternaryLabelColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            KeyAwareView { event in handleKeyEvent(event) }
        }
        .task(id: library.selectedIndex) {
            guard let index = library.selectedIndex else { image = nil; return }
            let isCacheHit = ImageLoader.shared.isFullImageCached(for: library.filteredItems[index])
            let intervalState = signposter.beginInterval("imageLoad", "\(isCacheHit ? "hit" : "miss")")
            await withTaskGroup(of: (Int, NSImage?).self) { group in
                for loadIndex in loadIndices(around: index) {
                    group.addTask {
                        (loadIndex, await ImageLoader.shared.fullImage(for: library.filteredItems[loadIndex]))
                    }
                }
                for await (loadIndex, loadedImage) in group {
                    if loadIndex == index {
                        image = loadedImage
                        signposter.endInterval("imageLoad", intervalState)
                    }
                }
            }
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        if event.keyCode == .escape {
            library.viewMode = .grid
            return true
        }
        guard let step = navigationStep(for: event) else { return false }
        let count = library.filteredItems.count
        guard count > 0, let current = library.selectedIndex else { return false }
        library.selectedIndex = max(0, min(count - 1, current + step))
        return true
    }

    /// Loads current index plus 4 ahead and 2 behind to warm the cache.
    private func loadIndices(around index: Int) -> [Int] {
        let count = library.filteredItems.count
        return (max(0, index - 2) ... min(count - 1, index + 4)).map { $0 }
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
