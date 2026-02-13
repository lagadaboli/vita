import Foundation

/// A node in the unified Health Graph.
/// Every data point (meal, glucose reading, HRV sample, behavioral event)
/// becomes a node, enabling temporal and causal queries.
public protocol HealthGraphNode: Identifiable, Sendable {
    var nodeID: String { get }
    var nodeType: HealthGraphNodeType { get }
    var timestamp: Date { get }
}

/// The type of node in the Health Graph.
public enum HealthGraphNodeType: String, Codable, Sendable {
    case physiological
    case glucose
    case meal
    case behavioral
    case symptom
    case causalPattern
}

/// Concrete node wrapper for storing heterogeneous nodes in the graph.
public struct AnyHealthGraphNode: HealthGraphNode, Sendable {
    public let nodeID: String
    public let nodeType: HealthGraphNodeType
    public let timestamp: Date
    public var id: String { nodeID }

    public init(nodeID: String, nodeType: HealthGraphNodeType, timestamp: Date) {
        self.nodeID = nodeID
        self.nodeType = nodeType
        self.timestamp = timestamp
    }

    /// Create a node from a PhysiologicalSample.
    public static func from(_ sample: PhysiologicalSample) -> AnyHealthGraphNode {
        AnyHealthGraphNode(
            nodeID: "physio_\(sample.id ?? 0)",
            nodeType: .physiological,
            timestamp: sample.timestamp
        )
    }

    /// Create a node from a GlucoseReading.
    public static func from(_ reading: GlucoseReading) -> AnyHealthGraphNode {
        AnyHealthGraphNode(
            nodeID: "glucose_\(reading.id ?? 0)",
            nodeType: .glucose,
            timestamp: reading.timestamp
        )
    }

    /// Create a node from a MealEvent.
    public static func from(_ meal: MealEvent) -> AnyHealthGraphNode {
        AnyHealthGraphNode(
            nodeID: "meal_\(meal.id ?? 0)",
            nodeType: .meal,
            timestamp: meal.timestamp
        )
    }

    /// Create a node from a BehavioralEvent.
    public static func from(_ event: BehavioralEvent) -> AnyHealthGraphNode {
        AnyHealthGraphNode(
            nodeID: "behavioral_\(event.id ?? 0)",
            nodeType: .behavioral,
            timestamp: event.timestamp
        )
    }
}
