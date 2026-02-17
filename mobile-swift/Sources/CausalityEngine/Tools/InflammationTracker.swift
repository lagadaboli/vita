import Foundation
import VITACore

/// Tool B: Checks for inflammation markers by comparing HRV against a 7-day baseline
/// and detecting post-prandial HRV suppression patterns.
///
/// Algorithm:
/// 1. Compute 7-day baseline HRV
/// 2. Compare current window HRV to baseline
/// 3. Check post-prandial HRV: if HRV 60-120min after meal < 80% of baseline, flag
/// 4. Check resting HR elevation above baseline
/// 5. Emit evidence split: 60% metabolic, 40% somatic
public struct InflammationTracker: AnalysisTool {
    public let name = "InflammationTracker"
    public let targetDebtTypes: Set<DebtType> = [.metabolic, .somatic]

    public init() {}

    public func analyze(
        hypotheses: [Hypothesis],
        healthGraph: HealthGraph,
        window: ClosedRange<Date>
    ) throws -> ToolObservation {
        // 7-day baseline HRV
        let baselineStart = window.lowerBound.addingTimeInterval(-7 * 24 * 3600)
        let baselineHRV = try healthGraph.querySamples(type: .hrvSDNN, from: baselineStart, to: window.lowerBound)
        let avgBaselineHRV = baselineHRV.isEmpty
            ? 50.0  // population norm fallback
            : baselineHRV.map(\.value).reduce(0, +) / Double(baselineHRV.count)

        // Current window HRV
        let currentHRV = try healthGraph.querySamples(type: .hrvSDNN, from: window.lowerBound, to: window.upperBound)
        let avgCurrentHRV = currentHRV.isEmpty
            ? avgBaselineHRV
            : currentHRV.map(\.value).reduce(0, +) / Double(currentHRV.count)

        let hrvDeviation = max((avgBaselineHRV - avgCurrentHRV) / avgBaselineHRV, 0)

        // Resting HR baseline comparison
        let baselineHR = try healthGraph.querySamples(type: .restingHeartRate, from: baselineStart, to: window.lowerBound)
        let avgBaselineHR = baselineHR.isEmpty ? 65.0 : baselineHR.map(\.value).reduce(0, +) / Double(baselineHR.count)

        let currentHR = try healthGraph.querySamples(type: .restingHeartRate, from: window.lowerBound, to: window.upperBound)
        let avgCurrentHR = currentHR.isEmpty ? avgBaselineHR : currentHR.map(\.value).reduce(0, +) / Double(currentHR.count)

        let hrElevation = avgBaselineHR > 0 ? max((avgCurrentHR - avgBaselineHR) / avgBaselineHR, 0) : 0

        // Post-prandial HRV suppression check
        let meals = try healthGraph.queryMeals(from: window.lowerBound, to: window.upperBound)
        var postPrandialScore = 0.0
        for meal in meals {
            let postMealHRV = currentHRV.filter {
                let delta = $0.timestamp.timeIntervalSince(meal.timestamp)
                return delta > 60 * 60 && delta < 120 * 60
            }
            if !postMealHRV.isEmpty {
                let avg = postMealHRV.map(\.value).reduce(0, +) / Double(postMealHRV.count)
                if avg < avgBaselineHRV * 0.8 {
                    postPrandialScore = max(postPrandialScore, (avgBaselineHRV - avg) / avgBaselineHRV)
                }
            }
        }

        let inflammationScore = hrvDeviation * 0.4 + postPrandialScore * 0.4 + hrElevation * 0.2

        let evidence: [DebtType: Double] = [
            .metabolic: inflammationScore * 0.6,
            .somatic: inflammationScore * 0.4,
        ]

        let dataConfidence = min(Double(currentHRV.count + baselineHRV.count) / 20.0, 1.0)

        return ToolObservation(
            toolName: name,
            evidence: evidence,
            confidence: dataConfidence,
            detail: "HRV deviation: \(Int(hrvDeviation * 100))%, Post-prandial: \(Int(postPrandialScore * 100))%, HR elevation: \(Int(hrElevation * 100))%"
        )
    }
}
