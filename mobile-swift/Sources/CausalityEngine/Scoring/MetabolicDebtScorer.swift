import Foundation
import VITACore

/// Computes the Metabolic Debt score: the delayed physiological cost of a meal.
/// Formula: GL × spike_magnitude × HRV_drop × cooking_modifier × timing_penalty
public struct MetabolicDebtScorer: Sendable {
    public init() {}

    /// Compute metabolic debt score (0-100) over a time window.
    public func score(healthGraph: HealthGraph, windowHours: Int) throws -> Double {
        let now = Date()
        let start = now.addingTimeInterval(-Double(windowHours) * 3600)

        let meals = try healthGraph.queryMeals(from: start, to: now)
        let glucose = try healthGraph.queryGlucose(from: start, to: now)
        let hrv = try healthGraph.querySamples(type: .hrvSDNN, from: start, to: now)

        guard !meals.isEmpty else { return 0 }

        // Baseline HRV
        let baselineStart = start.addingTimeInterval(-7 * 24 * 3600)
        let baselineHRV = try healthGraph.querySamples(type: .hrvSDNN, from: baselineStart, to: start)
        let avgBaseline = baselineHRV.isEmpty ? 50.0 : baselineHRV.map(\.value).reduce(0, +) / Double(baselineHRV.count)

        var totalDebt = 0.0

        for meal in meals {
            let gl = meal.estimatedGlycemicLoad ?? meal.computedGlycemicLoad
            let glFactor = min(gl / 50.0, 1.0)  // normalize: GL 50 = max

            // Find glucose spike magnitude after this meal
            let postMealGlucose = glucose.filter {
                let delta = $0.timestamp.timeIntervalSince(meal.timestamp)
                return delta > 0 && delta < 150 * 60
            }
            let peak = postMealGlucose.max(by: { $0.glucoseMgDL < $1.glucoseMgDL })?.glucoseMgDL ?? 100
            let nadir = postMealGlucose.filter { $0.timestamp > (postMealGlucose.max(by: { $0.glucoseMgDL < $1.glucoseMgDL })?.timestamp ?? Date()) }
                .min(by: { $0.glucoseMgDL < $1.glucoseMgDL })?.glucoseMgDL ?? peak
            let spikeMagnitude = min((peak - nadir) / 80.0, 1.0)  // 80mg swing = max

            // HRV drop after meal
            let postMealHRV = hrv.filter {
                let delta = $0.timestamp.timeIntervalSince(meal.timestamp)
                return delta > 60 * 60 && delta < 180 * 60
            }
            let avgPostMealHRV = postMealHRV.isEmpty ? avgBaseline : postMealHRV.map(\.value).reduce(0, +) / Double(postMealHRV.count)
            let hrvDrop = avgBaseline > 0 ? max((avgBaseline - avgPostMealHRV) / avgBaseline, 0) : 0

            // Cooking method modifier
            let cookingModifier: Double
            if let bio = meal.bioavailabilityModifier {
                cookingModifier = bio > 1.0 ? 0.8 : 1.2  // better bioavailability = less debt
            } else {
                cookingModifier = 1.0
            }

            // Timing penalty: late meals (after 8 PM) compound debt
            let hour = Calendar.current.component(.hour, from: meal.timestamp)
            let timingPenalty = hour >= 20 ? 1.3 : 1.0

            let mealDebt = glFactor * 0.3
                + spikeMagnitude * 0.3
                + hrvDrop * 0.25
                + (cookingModifier - 0.8) * 0.15

            totalDebt += mealDebt * timingPenalty
        }

        // Normalize to 0-100
        return min(totalDebt / Double(max(meals.count, 1)) * 100, 100)
    }
}
