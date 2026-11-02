import SwiftUI

/// Where the photo shown full size sits among the photos the user is
/// stepping through, such as "3 / 12", on a small panel. Placing it is left
/// to the full-size view that shows it.
struct PhotoPositionLabel: View {
    /// The shown photo's index among the photos, counting from zero.
    let index: Int
    let count: Int

    var body: some View {
        Text("\(index + 1) / \(count)")
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    PhotoPositionLabel(index: 2, count: 12)
        .padding()
}
