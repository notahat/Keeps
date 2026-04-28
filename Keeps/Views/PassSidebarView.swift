import SwiftUI

/// Sidebar listing all review passes with pick/reject/undecided counts. Tapping
/// a pass switches the main view to that pass's photos. The "Start Next Pass" button
/// creates a new pass from the current pass's undecided photos.
struct PassSidebarView: View {
    var library: FolderLibrary

    var body: some View {
        List(library.passes.indices, id: \.self, selection: passSelection) { index in
            PassRowView(
                number: index + 1,
                pass: library.passes[index],
                stats: library.stats(for: index)
            )
            .tag(index)
        }
        .navigationSplitViewColumnWidth(200)
        .safeAreaInset(edge: .bottom) {
            Button("Start Next Pass") {
                library.startNextPass()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!library.canStartNextPass)
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
            HStack(spacing: 10) {
                statCell(icon: Image(systemName: "photo"), count: stats.total)
                statCell(icon: markIcon(for: .pick).foregroundStyle(.green), count: stats.picks)
                statCell(icon: markIcon(for: .reject).foregroundStyle(.red), count: stats.rejects)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func statCell(icon: some View, count: Int) -> some View {
        HStack(spacing: 3) {
            icon
            Text("\(count)")
                .monospacedDigit()
                .frame(minWidth: 28, alignment: .leading)
        }
    }
}
