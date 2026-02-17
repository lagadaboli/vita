import Foundation
import VITACore

/// Gathered health data context for rule evaluation.
struct RuleContext: Sendable {
    let avgHRV: Double?
    let baselineHRV: Double?
    let hrvDropPercent: Double?
    let glucoseCrashDelta: Double?
    let currentGlucose: Double?
    let totalSleepHours: Double?
    let maxDopamineDebt: Double?
    let passiveMinutesLast3h: Double?
    let maxAQI: Int?
    let maxPollen: Int?
    let totalProteinGrams: Double?
    let maxMealGL: Double?
    let latestMealHour: Int?
}

/// Deterministic rule engine that evaluates bio-rules against HealthGraph data.
/// Used as the fallback when AI confidence is low or during cold start.
public struct BioRuleEngine: Sendable {
    private let rules: [BioRule]

    public init(rules: [BioRule] = DefaultRuleSet.rules) {
        self.rules = rules
    }

    public func evaluate(
        symptom: String,
        healthGraph: HealthGraph,
        window: ClosedRange<Date>? = nil
    ) throws -> [CausalExplanation] {
        let now = Date()
        let effectiveWindow = window ?? (now.addingTimeInterval(-6 * 3600)...now)
        let context = try gatherContext(healthGraph: healthGraph, window: effectiveWindow)

        var matchedRules: [(rule: BioRule, matchedCount: Int)] = []
        for rule in rules {
            let matched = rule.conditions.filter { evaluateCondition($0, context: context) }.count
            if matched == rule.conditions.count {
                matchedRules.append((rule, matched))
            }
        }

        // More conditions matched = more specific = higher priority
        matchedRules.sort { $0.matchedCount > $1.matchedCount }

        return matchedRules.map { rule, _ in
            CausalExplanation(
                symptom: symptom,
                causalChain: [rule.name],
                strength: rule.confidence,
                confidence: rule.confidence,
                narrative: "\(rule.explanation) \(rule.recommendation)"
            )
        }
    }

    // MARK: - Context Gathering

    private func gatherContext(
        healthGraph: HealthGraph,
        window: ClosedRange<Date>
    ) throws -> RuleContext {
        let start = window.lowerBound
        let end = window.upperBound

        // HRV
        let hrvSamples = try healthGraph.querySamples(type: .hrvSDNN, from: start, to: end)
        let avgHRV = hrvSamples.isEmpty ? nil : hrvSamples.map(\.value).reduce(0, +) / Double(hrvSamples.count)

        // Baseline HRV (7-day lookback)
        let baselineStart = start.addingTimeInterval(-7 * 24 * 3600)
        let baselineHRVSamples = try healthGraph.querySamples(type: .hrvSDNN, from: baselineStart, to: start)
        let baselineHRV = baselineHRVSamples.isEmpty ? nil : baselineHRVSamples.map(\.value).reduce(0, +) / Double(baselineHRVSamples.count)

        let hrvDropPercent: Double?
        if let avg = avgHRV, let baseline = baselineHRV, baseline > 0 {
            hrvDropPercent = ((baseline - avg) / baseline) * 100
        } else {
            hrvDropPercent = nil
        }

        // Glucose
        let glucose = try healthGraph.queryGlucose(from: start, to: end)
        let glucoseCrashDelta: Double?
        let currentGlucose: Double?
        if glucose.count >= 2 {
            let peak = glucose.max(by: { $0.glucoseMgDL < $1.glucoseMgDL })!
            let readingsAfterPeak = glucose.filter { $0.timestamp > peak.timestamp }
            let nadir = readingsAfterPeak.min(by: { $0.glucoseMgDL < $1.glucoseMgDL })
            glucoseCrashDelta = nadir.map { peak.glucoseMgDL - $0.glucoseMgDL }
            currentGlucose = glucose.last?.glucoseMgDL
        } else {
            glucoseCrashDelta = nil
            currentGlucose = glucose.last?.glucoseMgDL
        }

        // Sleep
        let sleepSamples = try healthGraph.querySamples(type: .sleepAnalysis, from: start, to: end)
        let totalSleepHours = sleepSamples.isEmpty ? nil : sleepSamples.map(\.value).reduce(0, +)

        // Behavior
        let behaviors = try healthGraph.queryBehaviors(from: start, to: end)
        let passiveEvents = behaviors.filter {
            $0.category == .passiveConsumption || $0.category == .zombieScrolling
        }
        let passiveMinutes = passiveEvents.reduce(0.0) { $0 + $1.duration / 60.0 }
        let maxDopamine = behaviors.compactMap(\.dopamineDebtScore).max()

        // Environment
        let environment = try healthGraph.queryEnvironment(from: start, to: end)
        let maxAQI = environment.map(\.aqiUS).max()
        let maxPollen = environment.map(\.pollenIndex).max()

        // Meals
        let meals = try healthGraph.queryMeals(from: start, to: end)
        let maxGL = meals.compactMap { $0.estimatedGlycemicLoad ?? $0.computedGlycemicLoad }.max()
        let totalProtein = meals.flatMap(\.ingredients).reduce(0.0) { total, ingredient in
            if ingredient.type == "protein" {
                return total + (ingredient.quantityGrams ?? 0)
            }
            return total
        }

        // Latest meal hour
        let calendar = Calendar.current
        let latestMealHour = meals.last.map { calendar.component(.hour, from: $0.timestamp) }

        return RuleContext(
            avgHRV: avgHRV,
            baselineHRV: baselineHRV,
            hrvDropPercent: hrvDropPercent,
            glucoseCrashDelta: glucoseCrashDelta,
            currentGlucose: currentGlucose,
            totalSleepHours: totalSleepHours,
            maxDopamineDebt: maxDopamine,
            passiveMinutesLast3h: passiveMinutes,
            maxAQI: maxAQI,
            maxPollen: maxPollen,
            totalProteinGrams: totalProtein,
            maxMealGL: maxGL,
            latestMealHour: latestMealHour
        )
    }

    // MARK: - Condition Evaluation

    private func evaluateCondition(_ condition: RuleCondition, context: RuleContext) -> Bool {
        switch condition.check {
        case .hrvBelow(let threshold):
            guard let avg = context.avgHRV else { return false }
            return avg < threshold

        case .hrvDropPercent(let threshold):
            guard let drop = context.hrvDropPercent else { return false }
            return drop > threshold

        case .glucoseCrashDelta(let threshold):
            guard let delta = context.glucoseCrashDelta else { return false }
            return delta > threshold

        case .glucoseBelow(let threshold):
            guard let current = context.currentGlucose else { return false }
            return current < threshold

        case .sleepBelow(let hours):
            guard let sleep = context.totalSleepHours else { return false }
            return sleep < hours

        case .dopamineDebtAbove(let threshold):
            guard let debt = context.maxDopamineDebt else { return false }
            return debt > threshold

        case .passiveMinutesAbove(let threshold):
            guard let minutes = context.passiveMinutesLast3h else { return false }
            return minutes > threshold

        case .aqiAbove(let threshold):
            guard let aqi = context.maxAQI else { return false }
            return aqi > threshold

        case .pollenAbove(let threshold):
            guard let pollen = context.maxPollen else { return false }
            return pollen > threshold

        case .proteinBelow(let grams):
            guard let protein = context.totalProteinGrams else { return false }
            return protein < grams

        case .glAbove(let threshold):
            guard let gl = context.maxMealGL else { return false }
            return gl > threshold

        case .lateMealAfter(let hour):
            guard let mealHour = context.latestMealHour else { return false }
            return mealHour >= hour
        }
    }
}
