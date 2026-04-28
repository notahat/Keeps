import SwiftUI

/// A small bar in the toolbar showing current ImageLoader queue depth relative
/// to its peak. The peak rises with the queue and resets to 1 when the queue
/// empties, so the bar fills the available width during a load burst and stays
/// proportional as it drains.
struct LoadGraphView: View {
    @State private var peak: Int = 1

    private var fillFraction: Double {
        Double(ImagePipeline.shared.queueCount) / Double(peak)
    }

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(.green)
                .frame(width: geometry.size.width * fillFraction, alignment: .leading)
                .animation(.easeInOut(duration: 0.2), value: fillFraction)
        }
        .frame(width: 48, height: 4)
        .background(.secondary.opacity(0.2))
        .clipShape(Capsule())
        .padding(.horizontal, 6)
        .onChange(of: ImagePipeline.shared.queueCount) { _, count in
            updatePeak(count: count)
        }
    }

    private func updatePeak(count: Int) {
        if count == 0 {
            peak = 1
        } else if count > peak {
            peak = count
        }
    }
}
