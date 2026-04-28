import AppKit
import SwiftUI

/// Full-window view of a single photo. Esc or G returns to the grid. Left/right
/// arrow keys and h/l navigate between photos; j/k also navigate linearly.
/// The current image loads at high priority; the surrounding preload window loads
/// at low priority and is left in the queue when navigating away.
struct SingleImageView: View {
    var library: FolderLibrary

    private enum MarkFeedback { case hidden, showing(FolderLibrary.Mark?) }

    @State private var image: NSImage?
    @State private var markFeedback: MarkFeedback = .hidden
    @State private var markFeedbackOpacity: Double = 0

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
        .overlay(alignment: .bottom) {
            if case let .showing(mark) = markFeedback {
                MarkFeedbackLabel(mark: mark)
                    .opacity(markFeedbackOpacity)
                    .padding(.bottom, 24)
                    .allowsHitTesting(false)
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
        .onChange(of: library.selectedIndex) {
            deprioritizeCurrent()
            loadWindow()
        }
        .onChange(of: library.lastMarkEvent) { _, event in
            flashMark(event?.mark)
        }
        .onReceive(NotificationCenter.default.publisher(for: ImagePipeline.imageLoadedNotification)) { notification in
            guard let item = selectedItem,
                  (notification.userInfo?[ImagePipeline.imageLoadedItemIDKey] as? UUID) == item.id
            else { return }
            image = ImagePipeline.shared.cachedImage(for: item, size: .full)
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
        image = ImagePipeline.shared.cachedImage(for: item, size: .full)
        ImagePipeline.shared.requestImage(for: item, size: .full)
        for idx in preloadIndices(around: index, in: items) {
            ImagePipeline.shared.prefetchImage(for: items[idx], size: .full)
        }
    }

    private func deprioritizeCurrent() {
        if let item = highPriorityItem {
            ImagePipeline.shared.deprioritizeImage(for: item, size: .full)
            highPriorityItem = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        if event.keyCode == .escape || event.charactersIgnoringModifiers == "g" {
            library.viewMode = .grid
            return true
        }
        guard let step = navigationStep(for: event) else { return false }
        let count = library.filteredItems.count
        guard count > 0, let current = library.selectedIndex else { return false }
        library.selectedIndex = max(0, min(count - 1, current + step))
        return true
    }

    private func flashMark(_ mark: FolderLibrary.Mark?) {
        markFeedback = .showing(mark)
        markFeedbackOpacity = 1
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 1.5)) {
                markFeedbackOpacity = 0
            }
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

private struct MarkFeedbackLabel: View {
    let mark: FolderLibrary.Mark?

    var body: some View {
        HStack(spacing: 8) {
            icon
            Text(message)
                .font(.title3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var icon: some View {
        markIcon(for: mark)
    }

    private var message: String {
        switch mark {
        case .pick: "Previous photo picked"
        case .reject: "Previous photo rejected"
        case nil: "Previous photo unmarked"
        }
    }
}
