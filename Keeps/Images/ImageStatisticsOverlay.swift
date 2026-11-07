import Darwin
import SwiftUI

/// A small panel of figures on image loading, for tuning it: the app's
/// memory footprint, what's cached at each size, the reads queued or
/// running, the cache hit rate, and how quickly recent steps at full size
/// turned sharp (see ImageLoadStatistics).
///
/// It shows only while the user has turned it on with the Debug menu's
/// Show Image Statistics, which debug builds alone have. It reads the
/// figures twice a second rather than observing them, so it never redraws
/// because an image loaded. Clicks pass through it. Where it sits is up to
/// the view that shows it.
struct ImageStatisticsOverlay: View {
    /// The user defaults key for whether the overlay shows. Changing it
    /// would lose the setting already saved under it.
    static let isShownKey = "showsImageStats"

    /// Whether the user has turned the overlay on.
    @AppStorage(Self.isShownKey) private var isShown = false

    var body: some View {
        if isShown {
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                ImageStatisticsPanel(snapshot: .current())
            }
            .allowsHitTesting(false)
        }
    }
}

/// The figures the overlay shows at one moment.
private struct ImageStatisticsSnapshot {
    /// The app's memory footprint in bytes, or nil if the system wouldn't
    /// say.
    let memoryFootprint: UInt64?

    /// What's cached at each size.
    let cacheContents: [ImageCache.Contents]

    /// How many reads are queued or running.
    let readCount: Int

    /// The hit rate and recent steps at full size.
    let statistics: ImageLoadStatistics

    /// Take the figures from the image pipeline and the system now.
    static func current() -> ImageStatisticsSnapshot {
        let pipeline = ImagePipeline.shared
        return ImageStatisticsSnapshot(
            memoryFootprint: readMemoryFootprint(),
            cacheContents: pipeline.cacheContents(),
            readCount: pipeline.readCount,
            statistics: pipeline.statistics
        )
    }

    /// Read the app's memory footprint in bytes, as Activity Monitor and
    /// Xcode's memory gauge report it, or return nil if the system won't
    /// say.
    private static func readMemoryFootprint() -> UInt64? {
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
private struct ImageStatisticsPanel: View {
    let snapshot: ImageStatisticsSnapshot

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
            row("Hit rate", Self.percentage(snapshot.statistics.hitRate))
            Divider()
            stepRows
        }
        .font(.caption.monospacedDigit())
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    /// The rows on recent steps at full size.
    @ViewBuilder private var stepRows: some View {
        let statistics = snapshot.statistics
        row("Sharp at once", Self.percentage(statistics.sharpStraightAwayShare))
        row("Time to sharp", "median \(Self.milliseconds(statistics.medianTimeToSharp)), "
            + "slowest \(Self.milliseconds(statistics.slowestTimeToSharp))")
        row("Moved on", "\(statistics.movedOnCount) of the last \(ImageLoadStatistics.recentStepLimit) steps")
    }

    /// Make a row of one labelled figure.
    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
        }
    }

    /// Format a number of bytes in whole megabytes, such as "364 MB".
    private static func megabytes(_ byteCount: Int) -> String {
        "\(byteCount / 1_000_000) MB"
    }

    /// Format a share as a whole percentage, or a dash when there's none.
    private static func percentage(_ share: Double?) -> String {
        share.map { "\(Int(($0 * 100).rounded()))%" } ?? "–"
    }

    /// Format a time in whole milliseconds, or a dash when there's none.
    private static func milliseconds(_ duration: Duration?) -> String {
        guard let duration else { return "–" }
        let (seconds, attoseconds) = duration.components
        return "\(seconds * 1000 + attoseconds / 1_000_000_000_000_000) ms"
    }
}

#Preview {
    var statistics = ImageLoadStatistics()
    for _ in 0 ..< 9 {
        statistics.recordLookup(isHit: true)
    }
    statistics.recordLookup(isHit: false)
    statistics.recordStep(.sharp(after: .zero))
    statistics.recordStep(.sharp(after: .milliseconds(42)))
    statistics.recordStep(.movedOn)
    return ImageStatisticsPanel(snapshot: ImageStatisticsSnapshot(
        memoryFootprint: 1_234_000_000,
        cacheContents: [
            ImageCache.Contents(size: .scaled(longestSideLength: 520), imageCount: 812, byteCount: 585_000_000),
            ImageCache.Contents(size: .full, imageCount: 7, byteCount: 364_000_000),
        ],
        readCount: 3,
        statistics: statistics
    ))
    .padding()
}
