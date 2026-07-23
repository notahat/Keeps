import AppKit
import SwiftUI

/// A lazy scrolling grid of photo cells. Owns the grid geometry (column
/// math), scroll-to-selection, keyboard focus, and the interpretation of
/// spatial navigation keys (arrows and h/j/k/l) into NavigationProposals.
/// All policy — what a proposal does to the selection, what any other key
/// means — belongs to the caller, as does the cell content. Knows nothing
/// about marks, filters, or any other workflow concept.
struct PhotoGridSurface<Cell: View>: View {
    var items: [PhotoItem]
    var selectedIndex: Int?
    var onNavigate: (NavigationProposal) -> Void

    /// Receives every key press that isn't a spatial navigation key.
    /// Returns true when the key was handled.
    var onKeyDown: (NSEvent) -> Bool

    var onTap: (_ index: Int, _ extendsRange: Bool) -> Void
    var onDoubleTap: (_ index: Int) -> Void
    @ViewBuilder var cell: (_ item: PhotoItem, _ index: Int) -> Cell

    @State private var columnCount: Int = 1
    @State private var keyView: KeyAwareView.ResponderView?

    private static var cellSize: CGFloat {
        CGFloat(ThumbnailImage.displaySize)
    }

    private let spacing: CGFloat = 12

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: Self.cellSize), spacing: spacing)]
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        cell(item, index)
                            .onTapGesture(count: 2) {
                                onDoubleTap(index)
                            }
                            // simultaneousGesture fires immediately without waiting for the
                            // double-tap timeout that onTapGesture(count: 1) would incur.
                            .simultaneousGesture(TapGesture().onEnded {
                                let isShiftHeld = NSApp.currentEvent?.modifierFlags.contains(.shift) == true
                                onTap(index, isShiftHeld)
                                keyView?.window?.makeFirstResponder(keyView)
                            })
                            .id(item.id)
                    }
                }
                // Measured inside the padding: the adaptive grid computes its
                // column count from this same unpadded width, so measuring the
                // padded view would over-count columns at some window widths.
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                    columnCount = max(1, Int((width + spacing) / (Self.cellSize + spacing)))
                }
                .padding(spacing)
            }
            .background {
                KeyAwareView(onKeyDown: { event in handleKeyEvent(event) }, onViewReady: { keyView = $0 })
            }
            .onAppear {
                if let selectedIndex {
                    scrollProxy.scrollTo(items[selectedIndex].id, anchor: .center)
                }
            }
            .onChange(of: selectedIndex) { _, index in
                if let index, items.indices.contains(index) {
                    withAnimation { scrollProxy.scrollTo(items[index].id, anchor: .center) }
                }
            }
        }
    }

    private enum Direction { case left, right, up, down }

    /// Turns spatial keys into NavigationProposals using the current column
    /// count; forwards everything else to onKeyDown.
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard let direction = direction(for: event),
              !items.isEmpty,
              let current = selectedIndex
        else { return onKeyDown(event) }
        let count = items.count
        let targetIndex = switch direction {
        case .left: max(0, current - 1)
        case .right: min(count - 1, current + 1)
        case .up: current - columnCount >= 0 ? current - columnCount : current
        case .down: current + columnCount < count ? current + columnCount : current
        }
        onNavigate(NavigationProposal(
            targetIndex: targetIndex,
            extendsRange: event.modifierFlags.contains(.shift)
        ))
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
