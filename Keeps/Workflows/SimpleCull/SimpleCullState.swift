import Foundation

/// The persisted state for the simple culling workflow, stored via
/// WorkflowPersistence under the workflow name "simple-cull". Uses photo
/// stems (filename without extension) rather than in-memory UUIDs so state
/// survives folder moves.
struct SimpleCullState: Codable, Equatable {
    static let workflowName = "simple-cull"

    var picks: [String]
    var rejects: [String]
}
