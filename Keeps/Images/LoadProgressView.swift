import SwiftUI

/// A small toolbar progress ring for the image pipeline's current burst of
/// loading (see LoadProgress). Hidden while nothing is loading, but it keeps
/// its space so the toolbar doesn't shift.
struct LoadProgressView: View {
    var body: some View {
        LoadProgressRing(fractionComplete: ImagePipeline.shared.loadProgress.fractionComplete)
    }
}

/// Draws the progress ring for a given fraction, with no tie to the image
/// pipeline, so it can be previewed. A nil fraction hides the ring but keeps
/// its space.
private struct LoadProgressRing: View {
    let fractionComplete: Double?

    var body: some View {
        ProgressView(value: fractionComplete ?? 0)
            .progressViewStyle(.circular)
            .controlSize(.small)
            .opacity(fractionComplete == nil ? 0 : 1)
    }
}

#Preview("Loading") {
    HStack(spacing: 16) {
        LoadProgressRing(fractionComplete: 0)
        LoadProgressRing(fractionComplete: 0.25)
        LoadProgressRing(fractionComplete: 0.5)
        LoadProgressRing(fractionComplete: 0.75)
        LoadProgressRing(fractionComplete: 1)
    }
    .padding()
}
