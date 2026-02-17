import Foundation
import VITACore

/// Determines the engine's maturity phase from data density and edge confidence.
public struct EngineMaturityTracker: Sendable {
    private let healthGraph: HealthGraph

    public init(healthGraph: HealthGraph) {
        self.healthGraph = healthGraph
    }

    public var currentPhase: MaturityPhase {
        get throws {
            let now = Date()
            let twoWeeksAgo = now.addingTimeInterval(-14 * 24 * 3600)
            let fourWeeksAgo = now.addingTimeInterval(-28 * 24 * 3600)
            let eightWeeksAgo = now.addingTimeInterval(-56 * 24 * 3600)

            let recentGlucose = try healthGraph.queryGlucose(from: twoWeeksAgo, to: now)
            let meals = try healthGraph.queryMeals(from: eightWeeksAgo, to: now)

            // Not enough data for any statistical reasoning
            if recentGlucose.count < 50 || meals.count < 14 {
                return .passive
            }

            // Check edge confidence for causal readiness
            let edges = try healthGraph.queryEdges(
                type: .mealToGlucose,
                from: fourWeeksAgo,
                to: now
            )
            let avgConfidence = edges.isEmpty
                ? 0
                : edges.map(\.confidence).reduce(0, +) / Double(edges.count)

            if avgConfidence < 0.5 {
                return .correlation
            }

            // Check if we have enough historical depth for active learning
            let olderGlucose = try healthGraph.queryGlucose(from: eightWeeksAgo, to: fourWeeksAgo)
            if olderGlucose.count < 100 {
                return .causal
            }

            return .active
        }
    }

    public func phaseConfig() throws -> PhaseConfig {
        let phase = try currentPhase
        switch phase {
        case .passive:
            return PhaseConfig(useReAct: false, useRules: true, useLLM: false, maxTools: 0)
        case .correlation:
            return PhaseConfig(useReAct: false, useRules: true, useLLM: false, maxTools: 1)
        case .causal:
            return PhaseConfig(useReAct: true, useRules: true, useLLM: false, maxTools: 3)
        case .active:
            return PhaseConfig(useReAct: true, useRules: true, useLLM: true, maxTools: 3)
        }
    }
}
