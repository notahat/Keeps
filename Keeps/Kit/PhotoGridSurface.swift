import AppKit
import SwiftUI

/// A lazy scrolling grid of photo cells. Owns the grid geometry (column
/// math), scroll-to-selection, keyboard focus, the interpretation of spatial
/// navigation keys (arrows and h/j/k/l) into NavigationProposals, and —
/// when the caller asks for it — resolving clicks and hovers on cell edges
/// into gaps between items (see GridHitTarget). All policy — what a proposal
/// does to the selection, what any other key or a gap click means — belongs
/// to the caller, as does the cell content. Knows nothing about marks,
/// filters, groups, or any other workflow concept.
struct PhotoGridSurface<Cell: View>: View {
    var items: [PhotoItem]
    var selectedIndex: Int?
    var onNavigate: (NavigationProposal) -> Void

    /// Receives every key press that isn't a spatial navigation key.
    /// Returns true when the key was handled.
    var onKeyDown: (NSEvent) -> Bool

    var onTap: (_ index: Int, _ extendsRange: Bool) -> Void
    var onDoubleTap: (_ index: Int) -> Void

    /// Receives clicks on a gap, identified by the index of the item after
    /// it. When nil, cell edges behave like the rest of the cell.
    var onGapTap: ((_ gapIndex: Int) -> Void)?

    /// Receives the gap under the pointer as it moves, or nil when the
    /// pointer is not over a gap.
    var onGapHover: ((_ gapIndex: Int?) -> Void)?

    @ViewBuilder var cell: (_ item: PhotoItem, _ index: Int) -> Cell

    @State private var columnCount: Int = 1
    @State private var keyView: KeyAwareView.ResponderView?

    private static var cellSize: CGFloat {
        PhotoGridMetrics.cellSize
    }

    private static var spacing: CGFloat {
        PhotoGridMetrics.spacing
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: Self.cellSize, maximum: Self.cellSize), spacing: Self.spacing)]
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: Self.spacing) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        interactiveCell(item: item, index: index)
                    }
                }
                // Measured inside the padding: the adaptive grid computes its
                // column count from this same unpadded width, so measuring the
                // padded view would over-count columns at some window widths.
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                    columnCount = max(1, Int((width + Self.spacing) / (Self.cellSize + Self.spacing)))
                }
                .padding(Self.spacing)
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

    /// The caller's cell with click, double-click, and hover handling
    /// attached.
    private func interactiveCell(item: PhotoItem, index: Int) -> some View {
        cell(item, index)
            .onTapGesture(count: 2, coordinateSpace: .local) { location in
                if case .item = hitTarget(at: location, index: index) {
                    onDoubleTap(index)
                }
            }
            // simultaneousGesture fires immediately without waiting for the
            // double-tap timeout that onTapGesture(count: 1) would incur.
            .simultaneousGesture(SpatialTapGesture().onEnded { value in
                handleTap(at: value.location, index: index)
            })
            .onContinuousHover { phase in
                guard let onGapHover else { return }
                switch phase {
                case let .active(location):
                    if case let .gap(gapIndex) = hitTarget(at: location, index: index) {
                        onGapHover(gapIndex)
                    } else {
                        onGapHover(nil)
                    }
                case .ended:
                    onGapHover(nil)
                }
            }
            .id(item.id)
    }

    /// Routes a single click to onGapTap or onTap, then takes keyboard focus.
    private func handleTap(at location: CGPoint, index: Int) {
        switch hitTarget(at: location, index: index) {
        case let .gap(gapIndex):
            onGapTap?(gapIndex)
        case .item:
            let isShiftHeld = NSApp.currentEvent?.modifierFlags.contains(.shift) == true
            onTap(index, isShiftHeld)
        }
        keyView?.window?.makeFirstResponder(keyView)
    }

    /// What a point within the cell at `index` targets. Edges only count as
    /// gaps when the caller handles gap clicks.
    private func hitTarget(at location: CGPoint, index: Int) -> GridHitTarget {
        guard onGapTap != nil else { return .item(index) }
        return GridHitTarget.resolve(offset: location.x, cellWidth: Self.cellSize, index: index)
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

/// The grid's fixed geometry, exposed so cells can draw chrome that lines up
/// with the gaps between them. Columns are fixed-width, so gaps never
/// stretch with the window.
enum PhotoGridMetrics {
    static var cellSize: CGFloat {
        CGFloat(ThumbnailImage.displaySize)
    }

    /// The space between cells, horizontally and vertically.
    static let spacing: CGFloat = 12
}
