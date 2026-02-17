import Foundation
import VITACore

/// Tool C: Evaluates behavioral data for dopamine debt patterns.
/// SCM-aware: if a glucose crash preceded scrolling, the scrolling is classified
/// as reactive (effect of fatigue, not cause).
///
/// Algorithm:
/// 1. Query behavioral events in window
/// 2. For each passive/zombie event, check if glucose crash preceded it by 0-30 min
/// 3. Split into genuineDigitalDebt vs reactiveScrollingMinutes
/// 4. Score only genuine digital debt
/// 5. If reactive > genuine, emit positive evidence for metabolic instead
public struct DigitalFrictionAnalyzer: AnalysisTool {
    public let name = "DigitalFrictionAnalyzer"
    public let targetDebtTypes: Set<DebtType> = [.digital]

    public init() {}

    public func analyze(
        hypotheses: [Hypothesis],
        healthGraph: HealthGraph,
        window: ClosedRange<Date>
    ) throws -> ToolObservation {
        let behaviors = try healthGraph.queryBehaviors(from: window.lowerBound, to: window.upperBound)
        let glucose = try healthGraph.queryGlucose(from: window.lowerBound, to: window.upperBound)

        let passiveEvents = behaviors.filter {
            $0.category == .passiveConsumption || $0.category == .zombieScrolling
        }

        guard !passiveEvents.isEmpty else {
            return ToolObservation(
                toolName: name,
                evidence: [.digital: 0.0],
                confidence: 0.8,
                detail: "No passive screen time detected"
            )
        }

        // Identify glucose crash timestamps
        let crashTimes = glucose
            .filter { $0.energyState == .crashing || $0.energyState == .reactiveLow }
            .map(\.timestamp)

        var genuineDigitalMinutes = 0.0
        var reactiveScrollingMinutes = 0.0

        for event in passiveEvents {
            let isReactive = crashTimes.contains { crashTime in
                // Crash happened 0-30 min before scrolling started -> reactive
                let delta = event.timestamp.timeIntervalSince(crashTime)
                return delta > 0 && delta < 30 * 60
            }

            if isReactive {
                reactiveScrollingMinutes += event.duration / 60.0
            } else {
                genuineDigitalMinutes += event.duration / 60.0
            }
        }

        let totalMinutes = genuineDigitalMinutes + reactiveScrollingMinutes
        let genuineRatio = totalMinutes > 0 ? genuineDigitalMinutes / totalMinutes : 0
        let digitalScore = min(genuineDigitalMinutes / 60.0, 1.0) * genuineRatio

        var evidence: [DebtType: Double] = [.digital: digitalScore]

        // If scrolling was mostly reactive, provide evidence for metabolic instead
        if reactiveScrollingMinutes > genuineDigitalMinutes {
            evidence[.metabolic] = 0.15
        }

        return ToolObservation(
            toolName: name,
            evidence: evidence,
            confidence: 0.8,
            detail: "Genuine digital: \(Int(genuineDigitalMinutes))min, Reactive scrolling: \(Int(reactiveScrollingMinutes))min"
        )
    }
}
