import Foundation
import VITACore

/// Composite scoring for SMS escalation eligibility.
/// Score = 0.5 * knownTriggerConfidence + 0.3 * stressContext + 0.2 * glucoseDeltaRate
/// Threshold: 0.75 — all three signals must be elevated to prevent alert fatigue.
public struct HighPainClassifier: Sendable {
    public init() {}

    /// Compute the composite pain probability score (0–1).
    public func score(
        explanation: CausalExplanation,
        healthGraph: HealthGraph
    ) -> Double {
        let now = Date()
        let window = now.addingTimeInterval(-6 * 3600)

        let triggerConfidence = knownTriggerConfidence(explanation: explanation)
        let stress = stressContext(healthGraph: healthGraph, from: window, to: now)
        let deltaRate = glucoseDeltaRate(healthGraph: healthGraph, from: window, to: now)

        return 0.5 * triggerConfidence + 0.3 * stress + 0.2 * deltaRate
    }

    /// Whether the score crosses the escalation threshold.
    public func shouldEscalate(
        explanation: CausalExplanation,
        healthGraph: HealthGraph
    ) -> Bool {
        score(explanation: explanation, healthGraph: healthGraph) >= 0.75
    }

    // MARK: - Component Scores

    /// Edge strength >= 0.65 from EdgeWeightLearner for this meal→glucose pattern.
    private func knownTriggerConfidence(explanation: CausalExplanation) -> Double {
        min(explanation.confidence, 1.0)
    }

    /// Binary: behavioral stressSignal event within +-4h.
    private func stressContext(healthGraph: HealthGraph, from start: Date, to end: Date) -> Double {
        let expandedStart = start.addingTimeInterval(-4 * 3600)
        let expandedEnd = end.addingTimeInterval(4 * 3600)

        do {
            let behaviors = try healthGraph.queryBehaviors(from: expandedStart, to: expandedEnd)
            let hasStress = behaviors.contains { $0.category == .stressSignal }
            return hasStress ? 1.0 : 0.0
        } catch {
            return 0.0
        }
    }

    /// Max glucose fall rate, normalized: >= 3 mg/dL/min → 1.0.
    private func glucoseDeltaRate(healthGraph: HealthGraph, from start: Date, to end: Date) -> Double {
        do {
            let readings = try healthGraph.queryGlucose(from: start, to: end)
            guard readings.count >= 2 else { return 0.0 }

            var maxFallRate = 0.0
            for i in 1..<readings.count {
                let prev = readings[i - 1]
                let curr = readings[i]
                let timeDelta = curr.timestamp.timeIntervalSince(prev.timestamp) / 60.0 // minutes
                guard timeDelta > 0 else { continue }

                let glucoseDelta = prev.glucoseMgDL - curr.glucoseMgDL // positive = falling
                let rate = glucoseDelta / timeDelta // mg/dL per minute

                if rate > maxFallRate {
                    maxFallRate = rate
                }
            }

            // Normalize: >= 3 mg/dL/min → 1.0
            return min(maxFallRate / 3.0, 1.0)
        } catch {
            return 0.0
        }
    }
}
