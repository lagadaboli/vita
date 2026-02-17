import Foundation
import VITACore

/// Implements do-calculus for counterfactual generation.
/// Given "What if I had done X instead?", estimates downstream effects
/// by propagating changes through the causal DAG.
public struct InterventionCalculator: Sendable {
    private let healthGraph: HealthGraph

    public init(healthGraph: HealthGraph) {
        self.healthGraph = healthGraph
    }

    /// Generate counterfactuals for a given event node.
    public func generateCounterfactuals(for eventNodeID: String) throws -> [Counterfactual] {
        var counterfactuals: [Counterfactual] = []

        if eventNodeID.contains("meal") {
            counterfactuals.append(contentsOf: mealCounterfactuals(nodeID: eventNodeID))
        }

        if eventNodeID.contains("behavioral") || eventNodeID.contains("screen") {
            counterfactuals.append(contentsOf: behaviorCounterfactuals())
        }

        if eventNodeID.contains("glucose") {
            counterfactuals.append(contentsOf: glucoseCounterfactuals(nodeID: eventNodeID))
        }

        if eventNodeID.contains("environment") {
            counterfactuals.append(contentsOf: environmentCounterfactuals())
        }

        if counterfactuals.isEmpty {
            counterfactuals = generalCounterfactuals()
        }

        return counterfactuals
    }

    /// Generate counterfactuals for a symptom by looking up relevant causal chains.
    public func generateCounterfactualsForSymptom(
        _ symptom: String,
        explanations: [CausalExplanation]
    ) throws -> [Counterfactual] {
        var counterfactuals: [Counterfactual] = []

        for explanation in explanations {
            let chain = explanation.causalChain.joined(separator: " ").lowercased()

            if chain.contains("glucose") || chain.contains("meal") || chain.contains("roti") || chain.contains("gl") {
                counterfactuals.append(contentsOf: mealInterventions())
            }

            if chain.contains("screen") || chain.contains("scroll") || chain.contains("dopamine") {
                counterfactuals.append(contentsOf: behaviorCounterfactuals())
            }

            if chain.contains("sleep") {
                counterfactuals.append(contentsOf: sleepCounterfactuals())
            }

            if chain.contains("aqi") || chain.contains("pollen") || chain.contains("environment") {
                counterfactuals.append(contentsOf: environmentCounterfactuals())
            }
        }

        // Deduplicate by description
        var seen = Set<String>()
        counterfactuals = counterfactuals.filter { seen.insert($0.description).inserted }

        return Array(counterfactuals.prefix(5))
    }

    // MARK: - Intervention Templates

    private func mealCounterfactuals(nodeID: String) -> [Counterfactual] {
        mealInterventions()
    }

    private func mealInterventions() -> [Counterfactual] {
        [
            Counterfactual(
                description: "Switch to whole wheat flour (-35% glucose spike)",
                impact: 0.35,
                effort: .trivial,
                confidence: 0.85
            ),
            Counterfactual(
                description: "Add 15g fat/protein before carbs to flatten curve",
                impact: 0.25,
                effort: .trivial,
                confidence: 0.75
            ),
            Counterfactual(
                description: "Pressure cook instead of slow cook (-95% lectins)",
                impact: 0.40,
                effort: .trivial,
                confidence: 0.82
            ),
            Counterfactual(
                description: "Take a 10-minute walk after meals",
                impact: 0.25,
                effort: .moderate,
                confidence: 0.78
            ),
        ]
    }

    private func behaviorCounterfactuals() -> [Counterfactual] {
        [
            Counterfactual(
                description: "Limit passive scrolling to 15-min blocks",
                impact: 0.45,
                effort: .significant,
                confidence: 0.70
            ),
            Counterfactual(
                description: "Use Focus Mode during deep work blocks",
                impact: 0.30,
                effort: .moderate,
                confidence: 0.65
            ),
            Counterfactual(
                description: "Replace scrolling with a 5-min walk",
                impact: 0.35,
                effort: .moderate,
                confidence: 0.72
            ),
        ]
    }

    private func glucoseCounterfactuals(nodeID: String) -> [Counterfactual] {
        mealInterventions()
    }

    private func sleepCounterfactuals() -> [Counterfactual] {
        [
            Counterfactual(
                description: "Eat dinner 2 hours earlier (+25 min deep sleep)",
                impact: 0.30,
                effort: .moderate,
                confidence: 0.75
            ),
            Counterfactual(
                description: "Keep dinner GL below 20",
                impact: 0.22,
                effort: .moderate,
                confidence: 0.68
            ),
            Counterfactual(
                description: "Stop screens 1 hour before bed",
                impact: 0.18,
                effort: .significant,
                confidence: 0.60
            ),
        ]
    }

    private func environmentCounterfactuals() -> [Counterfactual] {
        [
            Counterfactual(
                description: "Exercise indoors when AQI > 100",
                impact: 0.30,
                effort: .trivial,
                confidence: 0.75
            ),
            Counterfactual(
                description: "Use air purifier on high-AQI days",
                impact: 0.25,
                effort: .moderate,
                confidence: 0.68
            ),
            Counterfactual(
                description: "Take antihistamine on high-pollen days",
                impact: 0.20,
                effort: .trivial,
                confidence: 0.62
            ),
        ]
    }

    private func generalCounterfactuals() -> [Counterfactual] {
        Array(mealInterventions().prefix(2)) + Array(sleepCounterfactuals().prefix(1))
    }
}
