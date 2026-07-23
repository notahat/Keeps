import Foundation

/// A spatial selection move computed by a surface from a navigation key.
/// The surface owns the geometry (e.g. the grid's column math); the workflow
/// decides what actually happens to the selection.
struct NavigationProposal {
    /// The index in the surface's items array that the move points at.
    let targetIndex: Int

    /// True when shift was held, asking to extend a range selection.
    let extendsRange: Bool
}
