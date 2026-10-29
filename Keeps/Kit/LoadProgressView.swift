import SwiftUI

/// A small toolbar progress ring for the current burst of image loading (see
/// LoadProgress). Hidden while nothing is loading, but it keeps its space so
/// the toolbar doesn't shift.
struct LoadProgressView: View {
    @State private var progress = LoadProgress()

    var body: some View {
        ProgressView(value: progress.fractionComplete ?? 0)
            .progressViewStyle(.circular)
            .controlSize(.small)
            .opacity(progress.fractionComplete == nil ? 0 : 1)
            .onChange(of: ImagePipeline.shared.queueCount, initial: true) { _, count in
                progress.record(queueCount: count)
            }
    }
}
