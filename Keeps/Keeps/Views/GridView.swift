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
                    ForEach(Array(library.filteredItems.enumerated()), id: \.element.id) { index, item in
                        ThumbnailView(item: item, isSelected: library.selectedIndex == index, mark: library.marks[item.id])
                            .onTapGesture(count: 2) {
                                library.selectedIndex = index
                                library.viewMode = .single
                            }
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
            .onAppear {
                if let index = library.selectedIndex {
                    scrollProxy.scrollTo(library.filteredItems[index].id, anchor: .center)
                }
            }
            .onChange(of: library.selectedIndex) { _, index in
                if let index {
                    withAnimation { scrollProxy.scrollTo(library.filteredItems[index].id, anchor: .center) }
                }
            }
        }
    }

    private enum Direction { case left, right, up, down }

    private func markAction(for event: NSEvent) -> FolderLibrary.Mark?? {
        switch event.charactersIgnoringModifiers {
        case "p": return .some(.pick)
        case "x": return .some(.reject)
        case "u": return .some(nil)
        default:  return nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        if event.keyCode == .returnKey, library.selectedIndex != nil {
            library.viewMode = .single
            return true
        }
        if let mark = markAction(for: event), let index = library.selectedIndex {
            library.setMark(mark, for: library.filteredItems[index])
            library.selectedIndex = min(library.filteredItems.count - 1, index + 1)
            return true
        }
        guard let direction = direction(for: event) else { return false }
        let count = library.filteredItems.count
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
        case .leftArrow:  return .left
        case .rightArrow: return .right
        case .downArrow:  return .down
        case .upArrow:    return .up
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
