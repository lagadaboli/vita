import Foundation
import VITACore

/// Encodes domain knowledge about causal direction.
/// Hard constraints are not learnable — they are fixed by biology.
/// Soft defaults can be overridden with strong evidence.
public enum CausalDirection {
    /// Fixed causal constraints that cannot be overridden by data.
    public static let hardConstraints: [(cause: HealthGraphNodeType, cannotCause: HealthGraphNodeType)] = [
        // Digital behavior cannot directly cause glucose changes
        (.behavioral, .glucose),
        // Symptoms cannot cause meals (reverse causation trap)
        (.symptom, .meal),
        // Environment cannot cause behavioral choices directly
        (.environmental, .behavioral),
    ]

    /// The fixed causal ordering (topological sort).
    /// Nodes earlier in this list can cause nodes later in the list.
    public static let causalOrder: [HealthGraphNodeType] = [
        .meal,
        .environmental,
        .behavioral,
        .glucose,
        .physiological,
        .symptom,
    ]

    /// Validate that a proposed causal direction does not violate hard constraints.
    public static func isValid(from source: HealthGraphNodeType, to target: HealthGraphNodeType) -> Bool {
        // Check hard constraints
        for constraint in hardConstraints {
            if constraint.cause == source && constraint.cannotCause == target {
                return false
            }
        }
        return true
    }

    /// Check if source can cause target based on causal ordering.
    public static func canCause(_ source: HealthGraphNodeType, _ target: HealthGraphNodeType) -> Bool {
        guard let sourceIdx = causalOrder.firstIndex(of: source),
              let targetIdx = causalOrder.firstIndex(of: target) else { return false }
        return sourceIdx <= targetIdx && isValid(from: source, to: target)
    }
}
