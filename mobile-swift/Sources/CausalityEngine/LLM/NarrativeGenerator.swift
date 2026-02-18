import Foundation

/// Generates human-readable narratives from causal analysis.
/// Tries LLM first (Supportive Peer tone), falls back to template if LLM fails or output is ungrounded.
public struct NarrativeGenerator: Sendable {
    private let llm: (any LocalLLMService)?

    public init(llm: (any LocalLLMService)? = nil) {
        self.llm = llm
    }

    /// Generate a narrative for a hypothesis given the observations.
    /// Async: tries SLM → hallucination guard → template fallback.
    public func generate(
        symptom: String,
        hypothesis: Hypothesis,
        observations: [ToolObservation],
        topCounterfactual: Counterfactual? = nil
    ) async -> String {
        let context = ExplanationContext.from(
            symptom: symptom,
            hypothesis: hypothesis,
            observations: observations,
            counterfactual: topCounterfactual
        )

        // Try LLM path first
        if let llm, llm.isReady {
            do {
                let prompt = PromptTemplates.peerNarrativePrompt(context: context)
                let output = try await llm.generate(prompt: prompt, maxTokens: 120)
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)

                if !trimmed.isEmpty && isGrounded(trimmed, in: context) {
                    return trimmed
                }
            } catch {
                // Fall through to template
                #if DEBUG
                print("[NarrativeGenerator] LLM failed, using template: \(error)")
                #endif
            }
        }

        // Template fallback (Supportive Peer tone)
        return templateNarrative(symptom: symptom, hypothesis: hypothesis, observations: observations, counterfactual: topCounterfactual)
    }

    /// Synchronous template-only generation (for non-async contexts).
    public func generateSync(
        symptom: String,
        hypothesis: Hypothesis,
        observations: [ToolObservation]
    ) -> String {
        templateNarrative(symptom: symptom, hypothesis: hypothesis, observations: observations, counterfactual: nil)
    }

    // MARK: - Hallucination Guard

    /// Checks that at least one causal chain term appears in the SLM output.
    /// If the model hallucinated content unrelated to the actual evidence, this rejects it.
    func isGrounded(_ output: String, in context: ExplanationContext) -> Bool {
        let lowered = output.lowercased()

        // Check if any causal chain term appears in the output
        let chainTerms = context.causalChain.flatMap { step in
            step.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 3 }
        }

        let hasChainReference = chainTerms.contains { term in
            lowered.contains(term)
        }

        // Also accept if the symptom itself is referenced
        let symptomWords = context.symptom.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 }

        let hasSymptomReference = symptomWords.contains { word in
            lowered.contains(word)
        }

        return hasChainReference || hasSymptomReference
    }

    // MARK: - Template Fallback (Supportive Peer Tone)

    private func templateNarrative(
        symptom: String,
        hypothesis: Hypothesis,
        observations: [ToolObservation],
        counterfactual: Counterfactual?
    ) -> String {
        let confidence = Int(hypothesis.confidence * 100)
        let chainDesc = hypothesis.causalChain.joined(separator: " → ")
        let evidenceDetails = observations.map(\.detail).filter { !$0.isEmpty }

        let why: String
        let evidence: String
        let fix: String

        switch hypothesis.debtType {
        case .metabolic:
            why = "Looks like your \(symptom.lowercased()) is connected to what you ate recently"
            evidence = evidenceDetails.isEmpty
                ? "Your glucose and meal data point to a metabolic pattern (\(confidence)% confidence): \(chainDesc)."
                : "Here's what the data shows (\(confidence)% confidence): \(evidenceDetails.first!)."
            fix = counterfactual?.description ?? "A short walk after your next meal could help smooth things out."

        case .digital:
            why = "Your \(symptom.lowercased()) seems tied to your screen time patterns"
            evidence = evidenceDetails.isEmpty
                ? "Extended passive screen time has been building up attention fatigue (\(confidence)% confidence): \(chainDesc)."
                : "The data shows (\(confidence)% confidence): \(evidenceDetails.first!)."
            fix = counterfactual?.description ?? "Taking a quick break from screens when you notice the pull might help."

        case .somatic:
            why = "Your \(symptom.lowercased()) looks like it has roots in your environment or recovery"
            evidence = evidenceDetails.isEmpty
                ? "Sleep and environmental factors are playing a role (\(confidence)% confidence): \(chainDesc)."
                : "Here's what stands out (\(confidence)% confidence): \(evidenceDetails.first!)."
            fix = counterfactual?.description ?? "Getting some extra rest could make a real difference."
        }

        return "\(why). \(evidence) \(fix)"
    }
}
