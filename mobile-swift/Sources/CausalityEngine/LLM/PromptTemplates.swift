import Foundation

/// Structured prompt templates for the local SLM.
/// Uses Llama 3.2 Instruct chat template format with a "Supportive Peer" persona:
/// warm, specific, never-preachy. Choices, not commands.
public enum PromptTemplates {

    // MARK: - System Prompt

    private static let systemPrompt = """
    You are a supportive friend who understands health data. \
    Stay strictly within the provided evidence. \
    Do not add conditions, diseases, or medical advice not present in the input. \
    Never use clinical jargon. Speak like a knowledgeable peer, not a doctor. \
    Be warm but specific — always reference the actual numbers and foods from the data.
    """

    // MARK: - Peer Narrative (3-sentence: Why → Evidence → Fix)

    /// Generate a warm, grounded causal narrative from analysis results.
    /// Output structure: Why (cause) → Evidence (connection) → Fix (low-friction choice).
    public static func peerNarrativePrompt(context: ExplanationContext) -> String {
        """
        <|system|>
        \(systemPrompt)
        <|end|>
        <|user|>
        Explain why I'm experiencing "\(context.symptom)" in exactly 3 sentences:
        1. WHY: What caused it (use the cause below)
        2. EVIDENCE: How the data shows the connection (use the numbers below)
        3. FIX: One easy thing I could try next time (frame as a choice, not a command)

        Primary cause: \(context.primaryCause)
        Cause type: \(context.primaryCauseType)
        Confidence: \(Int(context.confidence * 100))%
        Causal chain: \(context.causalChain.joined(separator: " → "))
        Evidence: \(context.evidenceFact)
        \(context.glucoseContext.map { "Glucose peak: \($0.peakMgDL) mg/dL, nadir: \($0.nadirMgDL) mg/dL, delta: \($0.deltaMgDL) mg/dL over \($0.minutesToNadir) min" } ?? "")
        Suggested action: \(context.suggestedAction)
        <|end|>
        <|assistant|>
        """
    }

    // MARK: - Watch Nudge (1 sentence, ≤15 words)

    /// Generate a watch nudge: exactly 1 sentence, max 15 words.
    /// Format: "[Cause] caused [symptom]. [Action]?"
    public static func watchNudgePrompt(context: ExplanationContext) -> String {
        """
        <|system|>
        \(systemPrompt) Keep your response to exactly ONE sentence, maximum 15 words. Format: "[Cause] → [symptom]. [Action]?"
        <|end|>
        <|user|>
        Write a single watch notification (max 15 words) for:
        Symptom: \(context.symptom)
        Cause: \(context.primaryCause)
        Quick action: \(context.suggestedAction)
        <|end|>
        <|assistant|>
        """
    }

    // MARK: - Counterfactual

    /// Generate a counterfactual narrative in supportive peer tone.
    public static func counterfactualPrompt(
        intervention: String,
        expectedImpact: Double,
        causalChain: [String]
    ) -> String {
        """
        <|system|>
        \(systemPrompt)
        <|end|>
        <|user|>
        Given this causal chain: \(causalChain.joined(separator: " → "))

        If I had: \(intervention)
        Expected improvement: \(Int(expectedImpact * 100))%

        Write one friendly sentence about the expected outcome. Be specific with numbers. Frame it as encouragement, not a lecture.
        <|end|>
        <|assistant|>
        """
    }

    // MARK: - Legacy (kept for backward compatibility)

    /// Generate a causal narrative from analysis results.
    public static func narrativePrompt(
        symptom: String,
        debtType: DebtType,
        confidence: Int,
        causalChain: [String],
        observationDetails: [String]
    ) -> String {
        """
        <|system|>
        \(systemPrompt)
        <|end|>
        <|user|>
        Explain why I'm experiencing "\(symptom)" in 2-3 sentences. Be specific with numbers.

        Primary cause: \(debtType.rawValue) (\(confidence)% confidence)
        Causal chain: \(causalChain.joined(separator: " → "))
        Evidence: \(observationDetails.joined(separator: "; "))
        <|end|>
        <|assistant|>
        """
    }
}
