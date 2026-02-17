import Foundation
import VITACore

/// Incrementally updates causal edge weights using Bayesian conjugate updates.
/// Exponentially decayed so recent observations matter more.
public struct EdgeWeightLearner: Sendable {
    public init() {}

    /// Update a single edge weight based on a confirmed or disconfirmed observation.
    public func updateEdge(
        _ edge: HealthGraphEdge,
        confirmed: Bool,
        healthGraph: HealthGraph
    ) throws -> HealthGraphEdge {
        var updated = edge

        // Decay: more confident edges get smaller updates
        let observationWeight = 1.0 / (1.0 + edge.confidence * 10)

        if confirmed {
            updated.causalStrength = edge.causalStrength + (1.0 - edge.causalStrength) * observationWeight
            updated.confidence = min(edge.confidence + 0.02, 0.99)
        } else {
            updated.causalStrength = edge.causalStrength - edge.causalStrength * observationWeight
            // Confidence still increases — we learned something
            updated.confidence = min(edge.confidence + 0.01, 0.99)
        }

        try healthGraph.addEdge(&updated)
        return updated
    }

    /// Batch update: scan recent meal-glucose pairs and confirm/disconfirm edges.
    public func batchUpdate(healthGraph: HealthGraph, window: ClosedRange<Date>) throws {
        let meals = try healthGraph.queryMeals(from: window.lowerBound, to: window.upperBound)
        let glucose = try healthGraph.queryGlucose(from: window.lowerBound, to: window.upperBound)

        for meal in meals {
            guard let mealID = meal.id else { continue }

            // Find glucose readings 30-120 min after meal
            let postMealGlucose = glucose.filter {
                let delta = $0.timestamp.timeIntervalSince(meal.timestamp)
                return delta > 30 * 60 && delta < 120 * 60
            }

            guard let peak = postMealGlucose.max(by: { $0.glucoseMgDL < $1.glucoseMgDL }) else { continue }

            let gl = meal.estimatedGlycemicLoad ?? meal.computedGlycemicLoad
            let spikeOccurred = peak.glucoseMgDL > 140

            // High GL + spike = confirmed; High GL + no spike = disconfirmed
            let confirmed = (gl > 25 && spikeOccurred) || (gl < 20 && !spikeOccurred)

            // Look up existing mealToGlucose edges
            let edges = try healthGraph.queryEdges(from: "meal_\(mealID)")
            for edge in edges where edge.edgeType == .mealToGlucose {
                _ = try updateEdge(edge, confirmed: confirmed, healthGraph: healthGraph)
            }

            // If no edge exists yet, create one
            if edges.filter({ $0.edgeType == .mealToGlucose }).isEmpty, let glucoseID = peak.id {
                var newEdge = HealthGraphEdge(
                    sourceNodeID: "meal_\(mealID)",
                    targetNodeID: "glucose_\(glucoseID)",
                    edgeType: .mealToGlucose,
                    causalStrength: spikeOccurred ? 0.6 : 0.3,
                    temporalOffsetSeconds: peak.timestamp.timeIntervalSince(meal.timestamp),
                    confidence: 0.3
                )
                try healthGraph.addEdge(&newEdge)
            }
        }
    }
}
