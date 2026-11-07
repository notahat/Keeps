import AppKit
import SwiftUI

/// Lets the view it overlays be dragged out of the app as photos' files, the
/// same as dragging those files from Finder, so they can be dropped into
/// Lightroom, a Finder folder, or anything else that takes files. The drag
/// is drawn as a pile of the photos' thumbnails. A press that ends without
/// a drag is a click, which PhotoDragSource reports to `onClick`. The AppKit
/// view takes every press, so a click would never reach the view
/// underneath.
///
/// PhotoDragSource only starts drags and reports clicks. Its owner supplies
/// the photos to drag, decides what a click does, and draws the view
/// underneath. Dragging within the app does nothing.
struct PhotoDragSource: NSViewRepresentable {
    /// The photos whose files a drag carries.
    let photos: [PhotoItem]

    /// Called when a press ends without starting a drag.
    let onClick: () -> Void

    /// Make the AppKit view that starts the drags.
    func makeNSView(context _: Context) -> PhotoDragView {
        PhotoDragView()
    }

    /// Give the AppKit view the current photos to drag, and what to do on
    /// a click.
    func updateNSView(_ view: PhotoDragView, context _: Context) {
        view.photos = photos
        view.onClick = onClick
    }
}

/// The AppKit view behind PhotoDragSource, which starts a drag with one item
/// per photo, since SwiftUI's drag modifiers hand over only one.
final class PhotoDragView: NSView, NSDraggingSource {
    /// The photos whose files a drag carries.
    var photos: [PhotoItem] = []

    /// Called when a press ends without starting a drag.
    var onClick: () -> Void = {}

    /// Whether this press has already started a drag, since mouseDragged
    /// arrives for every move.
    private var hasStartedDrag = false

    /// Where the press began, in this view's coordinates.
    private var pressLocation = NSPoint.zero

    /// How far, in points, the pointer must move before a press becomes a
    /// drag. Without it, the slightest wobble during a click would start a
    /// drag, and the click would be lost.
    private static let dragThreshold: CGFloat = 4

    /// The longest side of each photo in the drag image, in points.
    private static let dragImageLength: CGFloat = 96

    /// False, so a press here doesn't move the window, and dragging moves the
    /// photos instead.
    override var mouseDownCanMoveWindow: Bool {
        false
    }

    /// Get ready for a new drag, noting where the press began. Overriding
    /// mouseDown also keeps the press here, rather than passing it on to the
    /// next responder as NSView does by default.
    override func mouseDown(with event: NSEvent) {
        hasStartedDrag = false
        pressLocation = convert(event.locationInWindow, from: nil)
    }

    /// Start the drag once the pointer has moved past the drag threshold.
    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let distance = hypot(location.x - pressLocation.x, location.y - pressLocation.y)
        guard !hasStartedDrag, distance >= Self.dragThreshold else { return }
        hasStartedDrag = true
        let items = photos.map { makeDraggingItem(for: $0, at: location) }
        let session = beginDraggingSession(with: items, event: event, source: self)
        session.draggingFormation = .pile
    }

    /// Report a click when the press ends without having started a drag.
    override func mouseUp(with _: NSEvent) {
        guard !hasStartedDrag else { return }
        onClick()
    }

    /// Copy outside the app, and refuse drops inside it.
    func draggingSession(
        _: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .outsideApplication ? .copy : []
    }

    /// Make the drag item for one photo's file, drawn as its thumbnail (or
    /// the file's icon if the thumbnail isn't loaded) centred on the pointer.
    private func makeDraggingItem(for photo: PhotoItem, at location: NSPoint) -> NSDraggingItem {
        let item = NSDraggingItem(pasteboardWriter: photo.sourceURL as NSURL)
        let image = ImagePipeline.shared.cachedImage(for: photo, size: .thumbnail)
            ?? NSWorkspace.shared.icon(forFile: photo.sourceURL.path)
        let size = Self.dragImageSize(for: image.size)
        let frame = NSRect(
            x: location.x - size.width / 2,
            y: location.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        item.setDraggingFrame(frame, contents: image)
        return item
    }

    /// Return an image's size scaled so its longest side is the drag image
    /// length, or a square of that length for an empty image.
    private static func dragImageSize(for imageSize: NSSize) -> NSSize {
        let longestSide = max(imageSize.width, imageSize.height)
        guard longestSide > 0 else { return NSSize(width: dragImageLength, height: dragImageLength) }
        let scale = dragImageLength / longestSide
        return NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
}
