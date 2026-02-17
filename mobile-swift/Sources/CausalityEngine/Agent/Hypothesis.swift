import Foundation

/// A causal hypothesis linking a symptom to a debt type with supporting evidence.
public struct Hypothesis: Sendable, Comparable {
    public let debtType: DebtType
    public let description: String
    public var confidence: Double
    public var causalChain: [String]
    public var supportingEvidence: [String]
    public var contradictingEvidence: [String]
    public let priorProbability: Double

    public init(
        debtType: DebtType,
        description: String,
        confidence: Double,
        causalChain: [String] = [],
        supportingEvidence: [String] = [],
        contradictingEvidence: [String] = [],
        priorProbability: Double = 0.33
    ) {
        self.debtType = debtType
        self.description = description
        self.confidence = confidence
        self.causalChain = causalChain
        self.supportingEvidence = supportingEvidence
        self.contradictingEvidence = contradictingEvidence
        self.priorProbability = priorProbability
    }

    public static func < (lhs: Hypothesis, rhs: Hypothesis) -> Bool {
        lhs.confidence < rhs.confidence
    }
}
