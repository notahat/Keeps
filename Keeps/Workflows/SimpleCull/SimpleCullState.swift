import Foundation

/// The persisted state for the simple culling workflow, stored via
/// WorkflowPersistence under the workflow name "simple-cull". Uses photo
/// stems (filename without extension) rather than in-memory UUIDs so state
/// survives folder moves.
///
/// Declared nonisolated because it is a plain value type with no actor
/// affinity; otherwise the target's main-actor default would isolate its
/// Equatable conformance and make comparisons from nonisolated contexts
/// (such as test assertions) a Swift 6 error.
nonisolated struct SimpleCullState: Codable, Equatable {
    static let workflowName = "simple-cull"

    var picks: [String]
    var rejects: [String]
}
