import AppKit
import SwiftUI

/// Lets the view it overlays be dragged out of the app as photos' files, the
/// same as dragging those files from Finder, so they can be dropped into
/// Lightroom, a Finder folder, or anything else that takes files. The drag
/// is drawn as a pile of the photos' thumbnails.
///
/// It only starts drags. Its owner supplies the photos to drag and draws
/// the view underneath. Dragging within the app does nothing.
struct PhotoDragSource: NSViewRepresentable {
    let photos: [PhotoItem]

    /// Makes the AppKit view that starts the drags.
    func makeNSView(context _: Context) -> PhotoDragView {
        PhotoDragView()
    }

    /// Gives the AppKit view the current photos to drag.
    func updateNSView(_ view: PhotoDragView, context _: Context) {
        view.photos = photos
    }
}

/// The AppKit view behind PhotoDragSource, which starts a drag with one item
/// per photo, since SwiftUI's drag modifiers hand over only one.
final class PhotoDragView: NSView, NSDraggingSource {
    var photos: [PhotoItem] = []

    /// Whether this press has already started a drag, since mouseDragged
    /// arrives for every move.
    private var hasStartedDrag = false

    /// The longest side of each photo in the drag image.
    private static let dragImageLength: CGFloat = 96

    /// Stops a press here from moving the window, so that dragging moves the
    /// photos instead.
    override var mouseDownCanMoveWindow: Bool {
        false
    }

    /// Gets ready for a new drag. Overriding this also keeps the press here,
    /// rather than passing it on to the next responder as NSView does by
    /// default.
    override func mouseDown(with _: NSEvent) {
        hasStartedDrag = false
    }

    /// Starts the drag on the first move of a press.
    override func mouseDragged(with event: NSEvent) {
        guard !hasStartedDrag, !photos.isEmpty else { return }
        hasStartedDrag = true
        let location = convert(event.locationInWindow, from: nil)
        let items = photos.map { makeDraggingItem(for: $0, at: location) }
        let session = beginDraggingSession(with: items, event: event, source: self)
        session.draggingFormation = .pile
    }

    /// Copies outside the app, and refuses drops inside it.
    func draggingSession(
        _: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .outsideApplication ? .copy : []
    }

    /// Makes the drag item for one photo's file, drawn as its thumbnail (or
    /// the file's icon if the thumbnail isn't loaded) centred on the pointer.
    private func makeDraggingItem(for photo: PhotoItem, at location: NSPoint) -> NSDraggingItem {
        let item = NSDraggingItem(pasteboardWriter: photo.sourceURL as NSURL)
        let image = ImagePipeline.shared.cachedImage(for: photo, size: ThumbnailImage.imageSize)
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

    /// An image's size scaled so its longest side is the drag image length.
    private static func dragImageSize(for imageSize: NSSize) -> NSSize {
        let longestSide = max(imageSize.width, imageSize.height)
        guard longestSide > 0 else { return NSSize(width: dragImageLength, height: dragImageLength) }
        let scale = dragImageLength / longestSide
        return NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
}
