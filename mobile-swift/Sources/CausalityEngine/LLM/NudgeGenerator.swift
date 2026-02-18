import Foundation

/// Generates concise watch nudge text (≤15 words).
/// Uses SLM when available, template fallback otherwise.
public struct NudgeGenerator: Sendable {
    public init() {}

    /// Generate nudge text. If SLM is ready, uses PromptTemplates.watchNudgePrompt.
    public func generate(
        symptom: String,
        explanation: CausalExplanation,
        llm: (any LocalLLMService)?
    ) async -> String {
        let context = ExplanationContext(
            symptom: symptom,
            primaryCause: explanation.causalChain.first ?? "recent activity",
            primaryCauseType: "unknown",
            confidence: explanation.confidence,
            causalChain: explanation.causalChain,
            evidenceFact: explanation.narrative,
            suggestedAction: "take a short break"
        )

        // Try LLM path
        if let llm, llm.isReady {
            do {
                let prompt = PromptTemplates.watchNudgePrompt(context: context)
                let output = try await llm.generate(prompt: prompt, maxTokens: 30)
                let trimmed = truncateToWords(output.trimmingCharacters(in: .whitespacesAndNewlines), maxWords: 15)
                if !trimmed.isEmpty {
                    return trimmed
                }
            } catch {
                // Fall through to template
            }
        }

        // Template fallback
        return templateNudge(symptom: symptom, cause: explanation.causalChain.first ?? "recent activity")
    }

    private func templateNudge(symptom: String, cause: String) -> String {
        let text = "That \(cause.lowercased()) likely caused your \(symptom.lowercased()). Short walk?"
        return truncateToWords(text, maxWords: 15)
    }

    private func truncateToWords(_ text: String, maxWords: Int) -> String {
        let words = text.split(separator: " ")
        if words.count <= maxWords { return text }
        var truncated = words.prefix(maxWords).joined(separator: " ")
        if !truncated.hasSuffix("?") && !truncated.hasSuffix(".") {
            truncated += "?"
        }
        return truncated
    }
}
