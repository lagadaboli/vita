import Foundation
import VITACore

/// Tool D: Analyzes sleep quality and correlates with late meals and screen time.
///
/// Algorithm:
/// 1. Query sleep samples, compute total hours and deviation from 7-day baseline
/// 2. Check for late meals (after 9 PM) with high GL
/// 3. Check for late-night screen time
/// 4. Emit somatic evidence for sleep deficit, metabolic if late meal contributed
public struct SleepQualityAnalyzer: AnalysisTool {
    public let name = "SleepQualityAnalyzer"
    public let targetDebtTypes: Set<DebtType> = [.somatic, .metabolic]

    public init() {}

    public func analyze(
        hypotheses: [Hypothesis],
        healthGraph: HealthGraph,
        window: ClosedRange<Date>
    ) throws -> ToolObservation {
        // Sleep data (look at a wider window for last night)
        let sleepStart = window.lowerBound.addingTimeInterval(-12 * 3600)
        let sleep = try healthGraph.querySamples(type: .sleepAnalysis, from: sleepStart, to: window.upperBound)
        let totalSleepHours = sleep.map(\.value).reduce(0, +)

        // Baseline sleep (7-day average)
        let baselineStart = window.lowerBound.addingTimeInterval(-7 * 24 * 3600)
        let baselineSleep = try healthGraph.querySamples(type: .sleepAnalysis, from: baselineStart, to: window.lowerBound)
        let daysWithSleep = Set(baselineSleep.map { Calendar.current.startOfDay(for: $0.timestamp) }).count
        let avgBaselineSleepHours = daysWithSleep > 0
            ? baselineSleep.map(\.value).reduce(0, +) / Double(daysWithSleep)
            : 7.5  // population norm

        let sleepDeficit = max(avgBaselineSleepHours - totalSleepHours, 0)
        let sleepDeficitScore = min(sleepDeficit / 3.0, 1.0)  // 3h deficit = max score

        // Late meal check
        let meals = try healthGraph.queryMeals(from: sleepStart, to: window.upperBound)
        let calendar = Calendar.current
        let lateMeals = meals.filter { meal in
            let hour = calendar.component(.hour, from: meal.timestamp)
            let gl = meal.estimatedGlycemicLoad ?? meal.computedGlycemicLoad
            return hour >= 21 && gl > 25
        }
        let lateMealScore = lateMeals.isEmpty ? 0.0 : 0.3

        // Late screen time check
        let behaviors = try healthGraph.queryBehaviors(from: sleepStart, to: window.upperBound)
        let lateScreen = behaviors.filter { event in
            let hour = calendar.component(.hour, from: event.timestamp)
            return hour >= 22 && (event.category == .passiveConsumption || event.category == .zombieScrolling)
        }
        let lateScreenScore = lateScreen.isEmpty ? 0.0 : 0.2

        var evidence: [DebtType: Double] = [
            .somatic: sleepDeficitScore * 0.6 + lateScreenScore,
        ]

        if !lateMeals.isEmpty {
            evidence[.metabolic] = lateMealScore
        }

        let dataConfidence = sleep.isEmpty ? 0.2 : min(Double(sleep.count) / 4.0, 1.0)

        return ToolObservation(
            toolName: name,
            evidence: evidence,
            confidence: dataConfidence,
            detail: "Sleep: \(String(format: "%.1f", totalSleepHours))h (baseline: \(String(format: "%.1f", avgBaselineSleepHours))h), Late meals: \(lateMeals.count), Late screens: \(lateScreen.count)"
        )
    }
}
