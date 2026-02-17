import Foundation

/// Generates human-readable narratives from causal analysis.
/// Uses a local LLM when available, falls back to template-based generation.
public struct NarrativeGenerator: Sendable {
    private let llm: (any LocalLLMService)?

    public init(llm: (any LocalLLMService)? = nil) {
        self.llm = llm
    }

    /// Generate a narrative for a hypothesis given the observations.
    public func generate(
        symptom: String,
        hypothesis: Hypothesis,
        observations: [ToolObservation]
    ) -> String {
        // Template-based narrative (LLM integration deferred to active phase)
        templateNarrative(symptom: symptom, hypothesis: hypothesis, observations: observations)
    }

    private func templateNarrative(
        symptom: String,
        hypothesis: Hypothesis,
        observations: [ToolObservation]
    ) -> String {
        let confidence = Int(hypothesis.confidence * 100)
        let chainDesc = hypothesis.causalChain.joined(separator: " → ")
        let evidenceDetails = observations.map(\.detail).filter { !$0.isEmpty }

        switch hypothesis.debtType {
        case .metabolic:
            let details = evidenceDetails.isEmpty
                ? "Your recent meal composition and glucose response are the primary drivers."
                : evidenceDetails.first!
            return "Your \(symptom.lowercased()) is primarily metabolic (\(confidence)% confidence). \(chainDesc). \(details)"

        case .digital:
            let details = evidenceDetails.isEmpty
                ? "Passive screen time has depleted your attention reserves."
                : evidenceDetails.first!
            return "Your \(symptom.lowercased()) appears driven by digital friction (\(confidence)% confidence). \(chainDesc). \(details)"

        case .somatic:
            let details = evidenceDetails.isEmpty
                ? "Environmental and recovery factors are contributing."
                : evidenceDetails.first!
            return "Your \(symptom.lowercased()) has environmental/somatic roots (\(confidence)% confidence). \(chainDesc). \(details)"
        }
    }
}
