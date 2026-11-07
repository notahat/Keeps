import AppKit
import os
import SwiftUI

/// One photo's full image, fitted to the space, with its neighbours
/// preloaded: the shown photo loads at high priority, and the 4 photos after
/// it and the 2 before it at low priority. Shows the photo's thumbnail while
/// the full image loads, or a spinner when there's no thumbnail either.
///
/// Draws and loads only. The caller handles keys and focus, draws anything
/// over the image, and changes `index` to move through `photos`. Knows
/// nothing about groups or keepers.
struct FullSizePhoto: View {
    let photos: [PhotoItem]
    let index: Int

    /// The shown photo's full image, which redraws this view when it loads.
    @State private var fullImage: WatchedImage?

    /// The shown photo's thumbnail, which stands in until the full image
    /// loads.
    @State private var thumbnail: WatchedImage?

    /// The photo being loaded at high priority, tracked so it can be
    /// deprioritised when the user moves on before it finishes.
    @State private var highPriorityPhoto: PhotoItem?

    /// The step to the shown photo while its full image is still loading,
    /// for timing how long it takes to turn sharp. Nil once it has.
    @State private var pendingStep: PendingStep?

    private var photo: PhotoItem {
        photos[index]
    }

    var body: some View {
        Group {
            // The thumbnail stands in while the full image loads, so there's
            // a photo to see straight away.
            if let shownImage = fullImage?.image ?? thumbnail?.image {
                Image(nsImage: shownImage)
                    .resizable()
                    .scaledToFit()
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text(photo.stem)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadPhotoAndNeighbours()
        }
        .onDisappear {
            deprioritizeHighPriorityLoad()
        }
        .onChange(of: index) {
            deprioritizeHighPriorityLoad()
            loadPhotoAndNeighbours()
        }
        .onChange(of: fullImage?.image) { _, loaded in
            if loaded != nil {
                finishTimingStep()
            }
        }
    }

    /// Watches the shown photo's images, loads its full image at high
    /// priority, and prefetches the photos around it.
    private func loadPhotoAndNeighbours() {
        highPriorityPhoto = photo
        fullImage = ImagePipeline.shared.watchedImage(for: photo, size: .full)
        startTimingStep(isSharp: fullImage?.image != nil)
        thumbnail = ImagePipeline.shared.watchedImage(for: photo, size: .thumbnail)
        ImagePipeline.shared.requestImage(for: photo, size: .full)
        for preloadIndex in preloadIndices() {
            ImagePipeline.shared.prefetchImage(for: photos[preloadIndex], size: .full)
        }
    }

    /// Starts timing a step to a new photo, recording the step before it as
    /// moved on if that never turned sharp. A step whose full image is
    /// already cached is recorded as sharp straight away.
    /// Each step is counted for the debug overlay and marked for
    /// Instruments.
    private func startTimingStep(isSharp: Bool) {
        if let pendingStep {
            ImagePipeline.shared.recordStep(.movedOn)
            ImageSignposts.endStep(pendingStep.signpost, isSharp: false)
        }
        if isSharp {
            ImagePipeline.shared.recordStep(.sharp(after: .zero))
            ImageSignposts.markSharpStep(to: photo.stem)
            pendingStep = nil
        } else {
            pendingStep = PendingStep(start: .now, signpost: ImageSignposts.beginStep(to: photo.stem))
        }
    }

    /// Records how long the step took to turn sharp, if it's being timed.
    private func finishTimingStep() {
        guard let pendingStep else { return }
        ImagePipeline.shared.recordStep(.sharp(after: .now - pendingStep.start))
        ImageSignposts.endStep(pendingStep.signpost, isSharp: true)
        self.pendingStep = nil
    }

    /// Drops the in-flight high-priority load back to prefetch priority.
    private func deprioritizeHighPriorityLoad() {
        guard let highPriorityPhoto else { return }
        ImagePipeline.shared.deprioritizeImage(for: highPriorityPhoto, size: .full)
        self.highPriorityPhoto = nil
    }

    /// The indices to preload: up to 4 ahead and 2 behind the shown photo.
    private func preloadIndices() -> [Int] {
        (max(0, index - 2) ... min(photos.count - 1, index + 4)).filter { $0 != index }
    }
}

/// A step to a photo whose full image is still loading: when the user
/// stepped to it, and its interval in Instruments.
private struct PendingStep {
    let start: ContinuousClock.Instant
    let signpost: OSSignpostIntervalState
}
