import Foundation
import VITACore

/// In-memory Directed Acyclic Graph built from HealthGraphEdges.
/// Provides path tracing and path strength computation for causal reasoning.
public struct CausalDAG: Sendable {
    /// Adjacency list: sourceNodeType -> [(target, edgeType, weight)]
    public struct Edge: Sendable {
        public let target: HealthGraphNodeType
        public let edgeType: HealthGraphEdge.EdgeType
        public let weight: Double
    }

    private let adjacency: [HealthGraphNodeType: [Edge]]

    /// Build the DAG from persisted edges, filtering by causal direction validity.
    public init(edges: [HealthGraphEdge]) {
        var adj: [HealthGraphNodeType: [Edge]] = [:]

        for edge in edges {
            let sourceType = Self.nodeType(from: edge.sourceNodeID)
            let targetType = Self.nodeType(from: edge.targetNodeID)

            guard let src = sourceType, let tgt = targetType else { continue }
            guard CausalDirection.isValid(from: src, to: tgt) else { continue }

            adj[src, default: []].append(Edge(
                target: tgt,
                edgeType: edge.edgeType,
                weight: edge.causalStrength
            ))
        }

        self.adjacency = adj
    }

    /// Trace all causal paths from a source node type to the symptom node type.
    public func tracePaths(from source: HealthGraphNodeType) -> [[HealthGraphNodeType]] {
        var paths: [[HealthGraphNodeType]] = []
        var currentPath: [HealthGraphNodeType] = [source]
        dfs(from: source, target: .symptom, currentPath: &currentPath, allPaths: &paths)
        return paths
    }

    /// Compute the strength of a causal path (product of edge weights along the path).
    public func pathStrength(_ path: [HealthGraphNodeType]) -> Double {
        guard path.count >= 2 else { return 0 }
        var strength = 1.0
        for i in 0..<(path.count - 1) {
            let from = path[i]
            let to = path[i + 1]
            let edgeWeight = adjacency[from]?.first(where: { $0.target == to })?.weight ?? 0
            strength *= edgeWeight
        }
        return strength
    }

    /// Get neighbors of a node type.
    public func neighbors(of nodeType: HealthGraphNodeType) -> [Edge] {
        adjacency[nodeType] ?? []
    }

    // MARK: - Private

    private func dfs(
        from current: HealthGraphNodeType,
        target: HealthGraphNodeType,
        currentPath: inout [HealthGraphNodeType],
        allPaths: inout [[HealthGraphNodeType]]
    ) {
        if current == target && currentPath.count > 1 {
            allPaths.append(currentPath)
            return
        }

        guard let edges = adjacency[current] else { return }
        for edge in edges {
            guard !currentPath.contains(edge.target) else { continue } // prevent cycles
            currentPath.append(edge.target)
            dfs(from: edge.target, target: target, currentPath: &currentPath, allPaths: &allPaths)
            currentPath.removeLast()
        }
    }

    /// Infer node type from node ID prefix.
    private static func nodeType(from nodeID: String) -> HealthGraphNodeType? {
        if nodeID.hasPrefix("physio_") { return .physiological }
        if nodeID.hasPrefix("glucose_") { return .glucose }
        if nodeID.hasPrefix("meal_") { return .meal }
        if nodeID.hasPrefix("behavioral_") { return .behavioral }
        if nodeID.hasPrefix("environment_") { return .environmental }
        if nodeID.hasPrefix("symptom_") { return .symptom }
        return nil
    }
}
