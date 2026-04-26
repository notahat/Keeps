import SwiftUI

/// A scrollable grid of photo thumbnails that loads lazily as cells come into view.
/// Handles keyboard navigation via arrow keys and vi keys (h/j/k/l).
struct GridView: View {
    var library: FolderLibrary

    @State private var columnCount: Int = 1

    private let cellSize: CGFloat = 260
    private let spacing: CGFloat = 12

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: cellSize), spacing: spacing)]
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(Array(library.items.enumerated()), id: \.element.id) { index, item in
                        ThumbnailView(item: item, isSelected: library.selectedIndex == index)
                            .onTapGesture { library.selectedIndex = index }
                            .id(item.id)
                    }
                }
                .padding(spacing)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                    columnCount = max(1, Int((width + spacing) / (cellSize + spacing)))
                }
            }
            .background {
                KeyAwareView { event in handleKeyEvent(event) }
            }
            .onChange(of: library.selectedIndex) { _, index in
                if let index {
                    withAnimation { scrollProxy.scrollTo(library.items[index].id, anchor: .center) }
                }
            }
        }
    }

    private enum Direction { case left, right, up, down }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard let direction = direction(for: event) else { return false }
        let count = library.items.count
        guard count > 0, let current = library.selectedIndex else { return false }
        library.selectedIndex = switch direction {
            case .left:  max(0, current - 1)
            case .right: min(count - 1, current + 1)
            case .up:    current - columnCount >= 0 ? current - columnCount : current
            case .down:  current + columnCount < count ? current + columnCount : current
        }
        return true
    }

    private func direction(for event: NSEvent) -> Direction? {
        switch event.keyCode {
        case 123: return .left
        case 124: return .right
        case 125: return .down
        case 126: return .up
        default: break
        }
        switch event.charactersIgnoringModifiers {
        case "h": return .left
        case "l": return .right
        case "j": return .down
        case "k": return .up
        default:  return nil
        }
    }
}
