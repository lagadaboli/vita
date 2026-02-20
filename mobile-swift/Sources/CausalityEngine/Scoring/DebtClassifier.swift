import Foundation

/// The three root-cause categories for symptoms.
public enum DebtType: String, Sendable, Codable, CaseIterable {
    case metabolic   // food-based: glucose spikes/crashes, HRV suppression from meals
    case digital     // behavior-based: zombie scrolling, dopamine debt
    case somatic     // context-based: environment, sleep deprivation, calendar stress
}

/// A debt type with its computed score after evidence aggregation.
public struct RankedDebt: Sendable {
    public let type: DebtType
    public let score: Double      // normalized 0-1
    public let rawScore: Double   // unnormalized

    public init(type: DebtType, score: Double, rawScore: Double) {
        self.type = type
        self.score = score
        self.rawScore = rawScore
    }
}

/// Aggregates observations from analysis tools into ranked debt scores.
/// Uses additive Bayesian updating: posterior = prior + Σ(evidence × confidence).
public struct DebtClassifier: Sendable {

    public init() {}

    public func classify(
        hypotheses: [Hypothesis],
        observations: [ToolObservation]
    ) -> [RankedDebt] {
        // Uniform prior
        var scores: [DebtType: Double] = [
            .metabolic: 0.33,
            .digital: 0.33,
            .somatic: 0.34,
        ]

        // Shift priors based on hypothesis generation.
        // Weight both the prior probability AND the hypothesis confidence so the
        // classifier's normalized score stays aligned with the displayed confidence.
        for h in hypotheses {
            scores[h.debtType, default: 0] += h.priorProbability * 0.2 + h.confidence * 0.3
        }

        // Accumulate evidence from tool observations
        for obs in observations {
            for (debtType, evidence) in obs.evidence {
                scores[debtType, default: 0] += evidence * obs.confidence
            }
        }

        // Clamp negatives to zero before normalizing
        for key in scores.keys {
            scores[key] = max(scores[key]!, 0)
        }

        let total = scores.values.reduce(0, +)
        guard total > 0 else { return [] }

        return scores.map { type, score in
            RankedDebt(type: type, score: score / total, rawScore: score)
        }.sorted { $0.score > $1.score }
    }
}
