import Foundation
import VITACore

/// Computes Digital Debt score adjusted for reactive scrolling.
/// Uses the existing dopamine debt formula but filters out reactive scrolling
/// that was caused by glucose crashes (SCM-aware).
public struct DigitalDebtScorer: Sendable {
    public init() {}

    /// Compute digital debt score (0-100) over a time window.
    public func score(healthGraph: HealthGraph, windowHours: Int) throws -> Double {
        let now = Date()
        let start = now.addingTimeInterval(-Double(windowHours) * 3600)

        let behaviors = try healthGraph.queryBehaviors(from: start, to: now)
        let glucose = try healthGraph.queryGlucose(from: start, to: now)

        let passiveEvents = behaviors.filter {
            $0.category == .passiveConsumption || $0.category == .zombieScrolling
        }

        guard !passiveEvents.isEmpty else { return 0 }

        // Identify crash times for reactive scrolling detection
        let crashTimes = glucose
            .filter { $0.energyState == .crashing || $0.energyState == .reactiveLow }
            .map(\.timestamp)

        var genuineMinutes = 0.0
        for event in passiveEvents {
            let isReactive = crashTimes.contains { crashTime in
                let delta = event.timestamp.timeIntervalSince(crashTime)
                return delta > 0 && delta < 30 * 60
            }
            if !isReactive {
                genuineMinutes += event.duration / 60.0
            }
        }

        // Use the existing dopamine debt formula components
        let maxDopamineDebt = passiveEvents.compactMap(\.dopamineDebtScore).max() ?? 0

        // Weight genuine screen time vs dopamine debt score
        let screenTimeFactor = min(genuineMinutes / 60.0, 1.0) * 60  // 0-60 contribution
        let dopamineFactor = maxDopamineDebt * 0.4  // 0-40 contribution

        return min(screenTimeFactor + dopamineFactor, 100)
    }
}
