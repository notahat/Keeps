import SwiftUI

/// What the sort screen shows once every group is done, in place of an empty
/// grid: a little celebration, and how many photos were kept.
struct AllDoneMessage: View {
    let keptCount: Int
    let photoCount: Int

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("All done!")
                .font(.largeTitle.bold())
            Text("You kept \(keptCount) of \(photoCount) photos. Nice work.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}
