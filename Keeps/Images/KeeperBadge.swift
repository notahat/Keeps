import SwiftUI

/// A white checkmark on a green circle, marking a keeper. Its colour is
/// shared, so anything else that stands for the keepers matches it.
struct KeeperBadge: View {
    /// The colour that stands for keepers.
    static let color = Color.green

    var size: CGFloat = 28

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Self.color)
            .font(.system(size: size))
            .shadow(radius: 2)
    }
}

#Preview("Keeper badge") {
    KeeperBadge()
        .padding()
        .background(.black)
}
