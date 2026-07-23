import SwiftUI

/// A scrollable grid of photo thumbnails that loads lazily as cells come into view.
/// Handles keyboard navigation via arrow keys and vi keys (h/j/k/l).
struct GridView: View {
    var library: FolderLibrary

    @State private var columnCount: Int = 1
    @State private var keyView: KeyAwareView.ResponderView?

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
                        SimpleCullCell(
                            item: item,
                            isSelected: item.id == library.selectedItemID,
                            isInSelectionRange: library.selectionRange?.contains(index) ?? false,
                            mark: library.mark(for: item.id)
                        )
                        .onTapGesture(count: 2) {
                            library.selectItem(at: index)
                            library.viewMode = .single
                        }
                        // simultaneousGesture fires immediately without waiting for the
                        // double-tap timeout that onTapGesture(count: 1) would incur.
                        .simultaneousGesture(TapGesture().onEnded {
                            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                                library.extendSelection(to: index)
                            } else {
                                library.selectItem(at: index)
                            }
                            keyView?.window?.makeFirstResponder(keyView)
                        })
                        .id(item.id)
                    }
                }
                .padding(spacing)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                    columnCount = max(1, Int((width + spacing) / (cellSize + spacing)))
                }
            }
            .background {
                KeyAwareView(onKeyDown: { event in handleKeyEvent(event) }, onViewReady: { keyView = $0 })
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

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        if event.keyCode == .returnKey, library.selectedIndex != nil {
            library.viewMode = .single
            return true
        }
        guard let direction = direction(for: event) else { return false }
        let count = library.filteredItems.count
        guard count > 0, let current = library.selectedIndex else { return false }
        let newIndex = switch direction {
        case .left: max(0, current - 1)
        case .right: min(count - 1, current + 1)
        case .up: current - columnCount >= 0 ? current - columnCount : current
        case .down: current + columnCount < count ? current + columnCount : current
        }
        if event.modifierFlags.contains(.shift) {
            library.extendSelection(to: newIndex)
        } else {
            library.selectItem(at: newIndex)
        }
        return true
    }

    private func direction(for event: NSEvent) -> Direction? {
        switch event.keyCode {
        case .leftArrow: return .left
        case .rightArrow: return .right
        case .downArrow: return .down
        case .upArrow: return .up
        default: break
        }
        // Use lowercased() so shift+vi-key also extends selection.
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "h": return .left
        case "l": return .right
        case "j": return .down
        case "k": return .up
        default: return nil
        }
    }
}
