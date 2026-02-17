import Foundation

/// A deterministic bio-rule: a set of conditions that, when all met,
/// produce a causal explanation with fixed confidence.
public struct BioRule: Sendable {
    public let id: String
    public let name: String
    public let conditions: [RuleCondition]
    public let conclusion: DebtType
    public let explanation: String
    public let recommendation: String
    public let confidence: Double

    public init(
        id: String,
        name: String,
        conditions: [RuleCondition],
        conclusion: DebtType,
        explanation: String,
        recommendation: String,
        confidence: Double
    ) {
        self.id = id
        self.name = name
        self.conditions = conditions
        self.conclusion = conclusion
        self.explanation = explanation
        self.recommendation = recommendation
        self.confidence = confidence
    }
}

/// A single condition that can be evaluated against health data.
public struct RuleCondition: Sendable {
    public let check: MetricCheck

    public init(_ check: MetricCheck) {
        self.check = check
    }

    public enum MetricCheck: Sendable {
        case hrvBelow(Double)
        case hrvDropPercent(Double)
        case glucoseCrashDelta(Double)
        case glucoseBelow(Double)
        case sleepBelow(hours: Double)
        case dopamineDebtAbove(Double)
        case passiveMinutesAbove(Double)
        case aqiAbove(Int)
        case pollenAbove(Int)
        case proteinBelow(grams: Double)
        case glAbove(Double)
        case lateMealAfter(hour: Int)
    }
}
