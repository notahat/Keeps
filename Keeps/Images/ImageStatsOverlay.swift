import Darwin
import SwiftUI

/// A small panel of figures on image loading, for tuning it: the app's
/// memory footprint, what's cached at each size, the reads queued or
/// running, the cache hit rate, and how quickly recent steps at full size
/// turned sharp (see ImageLoadStats).
///
/// It shows only while the user has turned it on with the Debug menu's
/// Show Image Stats, which debug builds alone have. It reads the figures
/// twice a second rather than observing them, so it never redraws because
/// an image loaded. Clicks pass through it. Where it sits is up to the view
/// that shows it.
struct ImageStatsOverlay: View {
    /// The user defaults key for whether the overlay shows.
    static let isShownKey = "showsImageStats"

    @AppStorage(Self.isShownKey) private var isShown = false

    var body: some View {
        if isShown {
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                ImageStatsPanel(snapshot: .current())
            }
            .allowsHitTesting(false)
        }
    }
}

/// The figures the overlay shows at one moment.
private struct ImageStatsSnapshot {
    let memoryFootprint: UInt64?
    let cacheContents: [ImageCache.Contents]
    let readCount: Int
    let stats: ImageLoadStats

    /// Takes the figures from the image pipeline and the system now.
    static func current() -> ImageStatsSnapshot {
        let pipeline = ImagePipeline.shared
        return ImageStatsSnapshot(
            memoryFootprint: currentMemoryFootprint(),
            cacheContents: pipeline.cacheContents(),
            readCount: pipeline.readCount,
            stats: pipeline.stats
        )
    }

    /// The app's memory footprint in bytes, as Activity Monitor and Xcode's
    /// memory gauge report it, or nil if the system won't say.
    private static func currentMemoryFootprint() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { infoPointer in
            infoPointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { pointer in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), pointer, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : nil
    }
}

/// Draws a snapshot's figures, with no tie to the pipeline, so it can be
/// previewed.
private struct ImageStatsPanel: View {
    let snapshot: ImageStatsSnapshot

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3) {
            row("Memory", snapshot.memoryFootprint.map { Self.megabytes(Int($0)) } ?? "unknown")
            ForEach(snapshot.cacheContents, id: \.size) { contents in
                row(
                    "Cached \(contents.size)",
                    "\(contents.imageCount) · \(Self.megabytes(contents.byteCount))"
                )
            }
            row("Reads", "\(snapshot.readCount) queued or running")
            row("Hit rate", Self.percentage(snapshot.stats.hitRate))
            Divider()
            stepRows
        }
        .font(.caption.monospacedDigit())
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    /// The rows on recent steps at full size.
    @ViewBuilder private var stepRows: some View {
        let stats = snapshot.stats
        row("Sharp at once", Self.percentage(stats.sharpStraightAwayShare))
        row("Time to sharp", "median \(Self.milliseconds(stats.medianTimeToSharp)), "
            + "slowest \(Self.milliseconds(stats.slowestTimeToSharp))")
        row("Moved on", "\(stats.movedOnCount) of the last \(ImageLoadStats.recentStepLimit) steps")
    }

    /// One labelled figure.
    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
        }
    }

    /// A number of bytes in megabytes, such as "364 MB".
    private static func megabytes(_ byteCount: Int) -> String {
        "\(byteCount / 1_000_000) MB"
    }

    /// A share as a whole percentage, or a dash when there's none.
    private static func percentage(_ share: Double?) -> String {
        share.map { "\(Int(($0 * 100).rounded()))%" } ?? "–"
    }

    /// A time in whole milliseconds, or a dash when there's none.
    private static func milliseconds(_ duration: Duration?) -> String {
        guard let duration else { return "–" }
        let (seconds, attoseconds) = duration.components
        return "\(seconds * 1000 + attoseconds / 1_000_000_000_000_000) ms"
    }
}

#Preview {
    var stats = ImageLoadStats()
    for _ in 0 ..< 9 {
        stats.recordLookup(isHit: true)
    }
    stats.recordLookup(isHit: false)
    stats.recordStep(.sharp(after: .zero))
    stats.recordStep(.sharp(after: .milliseconds(42)))
    stats.recordStep(.movedOn)
    return ImageStatsPanel(snapshot: ImageStatsSnapshot(
        memoryFootprint: 1_234_000_000,
        cacheContents: [
            ImageCache.Contents(size: .scaled(longestSideLength: 520), imageCount: 812, byteCount: 585_000_000),
            ImageCache.Contents(size: .full, imageCount: 7, byteCount: 364_000_000),
        ],
        readCount: 3,
        stats: stats
    ))
    .padding()
}
