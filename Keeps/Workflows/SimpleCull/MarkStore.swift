import Foundation

/// Flat per-photo marks for the simple culling workflow. One mark per photo:
/// setting a mark replaces any existing one, and nil clears it. Pure data
/// store — does not know about selection or persistence.
struct MarkStore {
    enum Mark: String, Codable { case pick, reject }

    private(set) var marks: [UUID: Mark] = [:]

    /// Returns the mark for a photo, or nil if unmarked.
    func mark(for id: UUID) -> Mark? {
        marks[id]
    }

    /// Sets, changes, or clears the mark for a photo. Passing nil unmarks.
    mutating func setMark(_ mark: Mark?, for id: UUID) {
        marks[id] = mark
    }

    /// Replaces all marks with restored state.
    mutating func applyRestored(marks: [UUID: Mark]) {
        self.marks = marks
    }
}
