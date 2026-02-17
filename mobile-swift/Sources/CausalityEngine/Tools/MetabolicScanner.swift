import Foundation
import VITACore

/// Tool A: Runs regression on the glucose curve to detect post-meal dips
/// that temporally correlate with the reported symptom.
///
/// Algorithm:
/// 1. Find glucose peak and post-peak nadir in the analysis window
/// 2. Compute crash severity = min(delta / 60, 1.0)
/// 3. Cross-reference with HRV: post-crash HRV drop >15% = strong confirmation
/// 4. Attribute to nearest meal within 30-150 min temporal window
/// 5. Score = 0.5 * crashSeverity + 0.3 * hrvDrop + 0.2 * mealAttribution
public struct MetabolicScanner: AnalysisTool {
    public let name = "MetabolicScanner"
    public let targetDebtTypes: Set<DebtType> = [.metabolic]

    public init() {}

    public func analyze(
        hypotheses: [Hypothesis],
        healthGraph: HealthGraph,
        window: ClosedRange<Date>
    ) throws -> ToolObservation {
        let glucose = try healthGraph.queryGlucose(from: window.lowerBound, to: window.upperBound)
        let meals = try healthGraph.queryMeals(from: window.lowerBound, to: window.upperBound)
        let hrv = try healthGraph.querySamples(type: .hrvSDNN, from: window.lowerBound, to: window.upperBound)

        guard glucose.count >= 3 else {
            return ToolObservation(
                toolName: name,
                evidence: [.metabolic: 0.0],
                confidence: 0.1,
                detail: "Insufficient glucose data (\(glucose.count) readings)"
            )
        }

        // Find peak and post-peak nadir
        let peak = glucose.max(by: { $0.glucoseMgDL < $1.glucoseMgDL })!
        let readingsAfterPeak = glucose.filter { $0.timestamp > peak.timestamp }
        let nadir = readingsAfterPeak.min(by: { $0.glucoseMgDL < $1.glucoseMgDL })

        let crashDelta = nadir.map { peak.glucoseMgDL - $0.glucoseMgDL } ?? 0
        let crashSeverity = min(max(crashDelta, 0) / 60.0, 1.0)

        // HRV confirmation: compare post-crash HRV to window average
        let avgHRV = hrv.isEmpty ? 0 : hrv.map(\.value).reduce(0, +) / Double(hrv.count)
        var hrvDrop = 0.0
        if let nadirReading = nadir, !hrv.isEmpty, avgHRV > 0 {
            let postCrashHRV = hrv.filter { $0.timestamp > nadirReading.timestamp }
            if !postCrashHRV.isEmpty {
                let postAvg = postCrashHRV.map(\.value).reduce(0, +) / Double(postCrashHRV.count)
                hrvDrop = max((avgHRV - postAvg) / avgHRV, 0)
            }
        }

        // Meal attribution: find meal 30-150 min before the crash nadir
        let relatedMeal = meals.first { meal in
            guard let nadirReading = nadir else { return false }
            let delta = nadirReading.timestamp.timeIntervalSince(meal.timestamp)
            return delta > 30 * 60 && delta < 150 * 60
        }

        let mealAttribution: Double = relatedMeal != nil ? 1.0 : 0.0
        let metabolicScore = crashSeverity * 0.5 + min(hrvDrop, 1.0) * 0.3 + mealAttribution * 0.2

        var evidence: [DebtType: Double] = [.metabolic: metabolicScore]
        // Strong metabolic signal suppresses digital hypothesis
        if metabolicScore > 0.7 {
            evidence[.digital] = -0.3
        }

        let dataConfidence = min(Double(glucose.count) / 12.0, 1.0)
        let mealDetail = relatedMeal.map { "Meal: \($0.source.rawValue)" } ?? "No meal attributed"

        return ToolObservation(
            toolName: name,
            evidence: evidence,
            confidence: dataConfidence,
            detail: "Crash: \(Int(crashDelta))mg/dL, HRV drop: \(Int(hrvDrop * 100))%, \(mealDetail)"
        )
    }
}
