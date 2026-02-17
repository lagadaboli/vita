import Foundation

/// Structured prompt templates for the local LLM.
/// Designed for small language models (1-3B parameters) — concise, factual, no personality.
public enum PromptTemplates {

    /// Generate a causal narrative from analysis results.
    public static func narrativePrompt(
        symptom: String,
        debtType: DebtType,
        confidence: Int,
        causalChain: [String],
        observationDetails: [String]
    ) -> String {
        """
        You are a health analyst. Given the following causal analysis, write a 2-3 sentence \
        explanation for the user. Be specific with numbers. Do not add personality or emojis.

        Symptom: \(symptom)
        Primary cause: \(debtType.rawValue) debt (confidence: \(confidence)%)
        Causal chain: \(causalChain.joined(separator: " → "))
        Evidence: \(observationDetails.joined(separator: "; "))

        Explanation:
        """
    }

    /// Generate a counterfactual narrative.
    public static func counterfactualPrompt(
        intervention: String,
        expectedImpact: Double,
        causalChain: [String]
    ) -> String {
        """
        Given this causal chain: \(causalChain.joined(separator: " → "))

        If the user had: \(intervention)
        Expected improvement: \(Int(expectedImpact * 100))%

        Write one sentence describing the expected outcome. Be specific.

        Result:
        """
    }
}
