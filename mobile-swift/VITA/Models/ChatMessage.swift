import Foundation
import CausalityEngine
import VITADesignSystem

/// A single message in the Ask VITA conversation thread.
struct ChatMessage: Identifiable {
    let id: UUID
    let role: Role
    let content: String

    // Structured analysis attached to VITA responses
    let causalExplanations: [CausalExplanation]
    let counterfactuals: [Counterfactual]
    let glucoseDataPoints: [GlucoseDataPoint]
    let mealAnnotations: [MealAnnotationPoint]
    let timestamp: Date

    enum Role {
        case user
        case vita
    }

    var hasAnalysis: Bool { !causalExplanations.isEmpty }

    // MARK: - Constructors

    static func user(_ text: String) -> ChatMessage {
        ChatMessage(
            id: UUID(),
            role: .user,
            content: text,
            causalExplanations: [],
            counterfactuals: [],
            glucoseDataPoints: [],
            mealAnnotations: [],
            timestamp: Date()
        )
    }

    static func vita(
        content: String,
        explanations: [CausalExplanation] = [],
        counterfactuals: [Counterfactual] = [],
        glucoseDataPoints: [GlucoseDataPoint] = [],
        mealAnnotations: [MealAnnotationPoint] = []
    ) -> ChatMessage {
        ChatMessage(
            id: UUID(),
            role: .vita,
            content: content,
            causalExplanations: explanations,
            counterfactuals: counterfactuals,
            glucoseDataPoints: glucoseDataPoints,
            mealAnnotations: mealAnnotations,
            timestamp: Date()
        )
    }

    static func vitaError(_ message: String) -> ChatMessage {
        vita(content: message)
    }
}
