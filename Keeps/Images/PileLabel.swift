import SwiftUI

/// The label under a PrintPile, such as "5 set aside": on a plain material,
/// or in white on a colour when given one, to make a pile stand out.
struct PileLabel: View {
    let text: String

    /// The capsule's colour, or nil for the plain material.
    var color: Color?

    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(color == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(.white))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
            .shadow(color: .black.opacity(0.4), radius: 2)
    }

    /// The capsule's fill: the colour, or the plain material without one.
    private var background: AnyShapeStyle {
        color.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.regularMaterial)
    }
}

#Preview("Plain pile label") {
    PileLabel(text: "12 to go")
        .padding()
        .background(.black)
}

#Preview("Coloured pile label") {
    PileLabel(text: "5 keepers", color: .green)
        .padding()
        .background(.black)
}
