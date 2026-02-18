import Foundation

/// Structured bridge between CausalityEngine analysis output and LLM prompt generation.
/// Keeps assembly logic out of NarrativeGenerator.
public struct ExplanationContext: Codable, Sendable {
    public let symptom: String
    public let primaryCause: String
    public let primaryCauseType: String
    public let confidence: Double
    public let causalChain: [String]
    public let evidenceFact: String
    public let suggestedAction: String
    public let glucoseContext: GlucoseContext?

    public struct GlucoseContext: Codable, Sendable {
        public let peakMgDL: Double
        public let nadirMgDL: Double
        public let deltaMgDL: Double
        public let minutesToNadir: Int

        public init(peakMgDL: Double, nadirMgDL: Double, deltaMgDL: Double, minutesToNadir: Int) {
            self.peakMgDL = peakMgDL
            self.nadirMgDL = nadirMgDL
            self.deltaMgDL = deltaMgDL
            self.minutesToNadir = minutesToNadir
        }
    }

    public init(
        symptom: String,
        primaryCause: String,
        primaryCauseType: String,
        confidence: Double,
        causalChain: [String],
        evidenceFact: String,
        suggestedAction: String,
        glucoseContext: GlucoseContext? = nil
    ) {
        self.symptom = symptom
        self.primaryCause = primaryCause
        self.primaryCauseType = primaryCauseType
        self.confidence = confidence
        self.causalChain = causalChain
        self.evidenceFact = evidenceFact
        self.suggestedAction = suggestedAction
        self.glucoseContext = glucoseContext
    }

    /// Factory: build from hypothesis + observations + optional counterfactual.
    public static func from(
        symptom: String,
        hypothesis: Hypothesis,
        observations: [ToolObservation],
        counterfactual: Counterfactual? = nil
    ) -> ExplanationContext {
        let evidenceDetails = observations.map(\.detail).filter { !$0.isEmpty }
        let evidenceFact = evidenceDetails.first ?? "Based on your recent health data patterns."

        let suggestedAction: String
        if let cf = counterfactual {
            suggestedAction = cf.description
        } else {
            switch hypothesis.debtType {
            case .metabolic:
                suggestedAction = "Maybe try a short walk after your next meal"
            case .digital:
                suggestedAction = "A quick break from screens might help"
            case .somatic:
                suggestedAction = "Getting some rest could make a difference"
            }
        }

        return ExplanationContext(
            symptom: symptom,
            primaryCause: hypothesis.description,
            primaryCauseType: hypothesis.debtType.rawValue,
            confidence: hypothesis.confidence,
            causalChain: hypothesis.causalChain,
            evidenceFact: evidenceFact,
            suggestedAction: suggestedAction
        )
    }
}
