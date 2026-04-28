import SwiftUI

/// Sidebar listing all review passes with pick/reject/undecided counts. Tapping
/// a pass switches the main view to that pass's photos. The "Commit Pass" button
/// creates a new pass from the current pass's undecided photos.
struct PassSidebarView: View {
    var library: FolderLibrary

    var body: some View {
        List(library.passes.indices, id: \.self, selection: passSelection) { index in
            PassRowView(
                number: index + 1,
                pass: library.passes[index],
                stats: library.stats(for: library.passes[index])
            )
            .tag(index)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Commit Pass") {
                library.advancePass()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!library.canAdvancePass)
            .padding()
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Passes")
    }

    private var passSelection: Binding<Int?> {
        Binding(
            get: { library.passes.isEmpty ? nil : library.currentPassIndex },
            set: { if let index = $0 { library.selectPass(index) } }
        )
    }
}

private struct PassRowView: View {
    let number: Int
    let pass: FolderLibrary.Pass
    let stats: FolderLibrary.PassStats

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Pass \(number)")
                .font(.headline)
            HStack(spacing: 12) {
                Image(systemName: "photo")
                Text("\(pass.photoIDs.count)")
                markIcon(for: .pick)
                    .foregroundStyle(.green)
                Text("\(stats.picks)")
                markIcon(for: .reject)
                    .foregroundStyle(.red)
                Text("\(stats.rejects)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
